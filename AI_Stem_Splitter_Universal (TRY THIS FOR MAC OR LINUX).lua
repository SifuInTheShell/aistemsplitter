--[[
    REAPER LOCAL AI ENGINEER (ANTIGRAVITY CORE)
    Role: Professional Audio Separation Engine (Universal - Win/Mac/Linux)
    
    INSTRUCTIONS:
    1. Install Python 3 and "demucs" (pip install demucs) on your system.
    2. Place this file in your REAPER Scripts folder.
    3. Open REAPER > Actions > Show Action List.
    4. "New Action" > "Load ReaScript..." > Select this file.
    5. Select an audio item and run.
]]

function get_os_info()
    local os_str = reaper.GetOS()
    local is_windows = os_str:match("Win") ~= nil
    local sep = is_windows and "\\" or "/"
    return is_windows, sep
end

function get_temp_dir(is_windows)
    if is_windows then
        local t = os.getenv("TEMP")
        if not t then t = "C:\\Windows\\Temp" end
        return t
    else
        -- En Mac/Linux, usamos la carpeta de REAPER para evitar bloqueos de seguridad
        local t = reaper.GetResourcePath() .. "/Scripts"
        return t
    end
end

function copy_file_lua(src, dest)
    local inp = io.open(src, "rb")
    local out = io.open(dest, "wb")
    
    if not inp then return false, "Error opening source" end
    if not out then inp:close(); return false, "Error creating destination" end
    
    local size = 4096 -- 4KB blocks
    while true do
        local block = inp:read(size)
        if not block then break end
        out:write(block)
    end
    
    inp:close()
    out:close()
    return true
end

function msg(m)
    reaper.ShowConsoleMsg(tostring(m) .. "\n")
end

function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

function main()
    -- 1. DETECT OS
    local is_windows, sep = get_os_info()
    -- Windows sets python to python.exe usually. Linux/Mac often python3.
    -- However, user might have aliased it. We'll try dynamic checking in a robust version, 
    -- but for now default to 'python' on Win and 'python3' on *nix.
    local python_cmd = is_windows and "python" or "python3"
    
    -- 2. GET SELECTED AUDIO
    local item = reaper.GetSelectedMediaItem(0, 0)
    if not item then
        reaper.ShowMessageBox("⚠️ Please select an audio clip first.", "AI Stem Splitter", 0)
        return
    end

    local take = reaper.GetActiveTake(item)
    if not take then
        reaper.ShowMessageBox("⚠️ The selected item does not have an active take.", "AI Stem Splitter", 0)
        return
    end

    -- Get source file path
    local source = reaper.GetMediaItemTake_Source(take)
    local file_path = reaper.GetMediaSourceFileName(source, "")
    
    if not file_path or file_path == "" then
        reaper.ShowMessageBox("⚠️ Could not read source file.", "AI Stem Splitter", 0)
        return
    end

    -- Get item position for alignment
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

    -- Parse filename (handle both separators just in case)
    local filename_ext = file_path:match(".*[/\\](.*)") or file_path
    local song_name = filename_ext:match("(.+)%.[^%.]+") or filename_ext

    -- 3. SETUP TEMP WORKSPACE
    local temp_root = get_temp_dir(is_windows)
    local work_dir = temp_root .. sep .. "IA_Stems_Temp"
    
    -- Create directory safely
    -- Windows: mkdir "path" > nul 2>&1
    -- *nix: mkdir -p "path"
    local mkdir_cmd
    if is_windows then
        mkdir_cmd = 'mkdir "' .. work_dir .. '" > nul 2>&1'
    else
        mkdir_cmd = 'mkdir -p "' .. work_dir .. '"'
    end
    
    -- Ejecutamos la creación y verificamos
    os.execute(mkdir_cmd)
    
    -- Pequeña pausa para que el sistema registre la carpeta (útil en Mac)
    if not is_windows then os.execute("sleep 0.1") end

    -- Si la carpeta no se creó, intentamos un plan B
    if not file_exists(work_dir) and not is_windows then
        work_dir = "/Users/Shared/IA_Stems_Temp" -- Carpeta compartida, siempre accesible
        os.execute('mkdir -p "' .. work_dir .. '"')
    end
    
    -- Temp input file
    -- Note: We use a fixed name "audio_proceso.wav" to avoid special character issues in shell
    local temp_input_filename = "audio_proceso.wav"
    local temp_input_path = work_dir .. sep .. temp_input_filename
    
    reaper.ShowConsoleMsg("\nAI Stem Splitter (Universal)\n")
    reaper.ShowConsoleMsg("OS: " .. reaper.GetOS() .. "\n")
    reaper.ShowConsoleMsg("🔹 Copying to TEMP: " .. work_dir .. "...\n")
    
    -- Copy File
    local success, err_msg = copy_file_lua(file_path, temp_input_path)
    if not success then
        reaper.ShowMessageBox("Error copying file:\n" .. (err_msg or "Unknown") .. "\n\nSource: " .. file_path, "Fatal Error", 0)
        return
    end

    -- 4. EXECUTE DEMUCS
    local model_name = "htdemucs_6s"
    local script_path
    local execute_cmd
    
    if is_windows then
        -- Windows Batch
        script_path = work_dir .. "\\run_demucs.bat"
        local f = io.open(script_path, "w")
        if f then
            f:write("@echo off\n")
            f:write("chcp 65001 > nul\n")
            f:write("cd /d \"" .. work_dir .. "\"\n")
            f:write("echo Processing: " .. song_name .. "\n")
            f:write(python_cmd .. ' -m demucs.separate -n ' .. model_name .. ' "' .. temp_input_filename .. '" -o .\n')
            f:write("if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%\n")
            f:write("exit 0\n")
            f:close()
        end
        execute_cmd = 'cmd /C "' .. script_path .. '"'
    else
        -- Mac/Linux Bash
        script_path = work_dir .. "/run_demucs.sh"
        local f = io.open(script_path, "w")
        if f then
            f:write("#!/bin/bash\n")
            -- Ensure PATH includes common locations just in case
            f:write("export PATH=$PATH:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin\n")
            f:write("cd \"" .. work_dir .. "\"\n")
            f:write("echo \"Processing: " .. song_name .. "\"\n")
            f:write(python_cmd .. " -m demucs.separate -n " .. model_name .. " \"" .. temp_input_filename .. "\" -o .\n")
            f:close()
        end
        -- chmod +x
        os.execute("chmod +x \"" .. script_path .. "\"")
        execute_cmd = '"' .. script_path .. '"'
    end
    
    reaper.ShowConsoleMsg("🔹 Running Demucs...\n")
    reaper.ShowConsoleMsg("Cmd: " .. execute_cmd .. "\n")
    
    -- Execute blocking
    local retval = os.execute(execute_cmd)
    
    -- Cleanup scripts/input
    os.remove(script_path)
    os.remove(temp_input_path)
    
    -- 5. IMPORT RESULTS
    -- Demucs output structure: work_dir/model_name/audio_proceso/stem.wav
    -- Note: on Mac/Linux, paths are case-sensitive. "audio_proceso" comes from input filename without ext.
    -- We used "audio_proceso.wav" as input, so folder is "audio_proceso".
    
    local stem_folder_name = "audio_proceso"
    local stems_dir = work_dir .. sep .. model_name .. sep .. stem_folder_name
    
    -- Verify check file
    local check_file = stems_dir .. sep .. "vocals.wav"
    if not file_exists(check_file) then
        check_file = stems_dir .. sep .. "vocals.mp3"
    end
    
    if file_exists(check_file) then
        reaper.ShowConsoleMsg("✅ Processing finished. Importing tracks...\n")
        
        reaper.Undo_BeginBlock()
        
        -- Create mother folder track
        local num_tracks = reaper.GetNumTracks()
        reaper.InsertTrackAtIndex(num_tracks, true)
        local folder_tr = reaper.GetTrack(0, num_tracks)
        
        reaper.GetSetMediaTrackInfo_String(folder_tr, "P_NAME", "STEMS: " .. song_name, true)
        reaper.SetMediaTrackInfo_Value(folder_tr, "I_FOLDERDEPTH", 1) 
        
        local instruments = {"vocals", "drums", "bass", "guitar", "piano", "other"}
        
        reaper.Main_OnCommand(40297, 0) -- Unselect all
        
        for _, inst in ipairs(instruments) do
            local stem_path_wav = stems_dir .. sep .. inst .. ".wav"
            local stem_path_mp3 = stems_dir .. sep .. inst .. ".mp3"
            local final_path = nil
            
            if file_exists(stem_path_wav) then final_path = stem_path_wav
            elseif file_exists(stem_path_mp3) then final_path = stem_path_mp3 end
            
            if final_path then
                local tr_idx = reaper.GetNumTracks()
                reaper.InsertTrackAtIndex(tr_idx, true)
                local tr = reaper.GetTrack(0, tr_idx)
                
                reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", inst:upper(), true)
                reaper.SetOnlyTrackSelected(tr)
                reaper.SetEditCurPos(pos, false, false)
                
                local success = reaper.InsertMedia(final_path, 0)
                
                if success == 1 then
                    local new_item = reaper.GetSelectedMediaItem(0, 0)
                    if new_item then
                        local take = reaper.GetActiveTake(new_item)
                        if take then
                            reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", song_name .. " - " .. inst, true)
                        end
                    end
                else
                    reaper.ShowConsoleMsg("⚠️ Error importing: " .. final_path .. "\n")
                end
            end
        end
        
        -- Close Folder
        local last_tr = reaper.GetTrack(0, reaper.GetNumTracks() - 1)
        reaper.SetMediaTrackInfo_Value(last_tr, "I_FOLDERDEPTH", -1)
        
        reaper.Undo_EndBlock("Import AI Stems", -1)
        reaper.UpdateArrange()
        reaper.ShowConsoleMsg("🚀 Done!\n")
    else
        reaper.ShowMessageBox("AI finished, but files not found.\nPath:\n" .. stems_dir, "Error", 0)
    end
end

main()
