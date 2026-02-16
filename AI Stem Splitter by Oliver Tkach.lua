--[[
    REAPER LOCAL AI ENGINEER (ANTIGRAVITY CORE)
    Role: Professional Audio Separation Engine (High-Fidelity)
    
    INSTRUCTIONS:
    1. Place this file in your REAPER Scripts folder (or anywhere).
    2. Open REAPER > Actions > Show Action List.
    3. Click "New Action" > "Load ReaScript..." and select this file.
    4. Select an audio item and run the script.
]]

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

function main()
    -- 1. OBTENER AUDIO SELECCIONADO
    local item = reaper.GetSelectedMediaItem(0, 0)
    if not item then
        reaper.ShowMessageBox("⚠️ Please select an audio clip first.", "AI Stem Splitter by Oliver Tkach", 0)
        return
    end

    -- 2. RUTAS Y POSICIÓN
    local take = reaper.GetActiveTake(item)
    if not take then
        reaper.ShowMessageBox("⚠️ The selected item does not have an active take.", "AI Stem Splitter by Oliver Tkach", 0)
        return
    end

    -- Get source file path
    local source = reaper.GetMediaItemTake_Source(take)
    local file_path = reaper.GetMediaSourceFileName(source, "")
    
    if not file_path or file_path == "" then
        reaper.ShowMessageBox("⚠️ Could not read source file.", "AI Stem Splitter by Oliver Tkach", 0)
        return
    end

    -- Get item position for alignment
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

    -- Prepare paths (Windows style separators handled by os.execute mostly, but let's be safe)
    -- Lua pattern matching for directory
    local input_dir = file_path:match("(.*[/\\])")
    local filename_ext = file_path:match(".*[/\\](.*)")
    local song_name = filename_ext:match("(.+)%.[^%.]+") or filename_ext -- Remove extension

    -- 3. EJECUTAR DEMUCS (MODO UNIVERSAL TEMP)
    -- Usamos la carpeta TEMP del sistema que garantiza escritura sin permisos de admin
    local temp_root = os.getenv("TEMP")
    if not temp_root then temp_root = "C:\\Windows\\Temp" end
    
    local work_dir = temp_root .. "\\IA_Stems_Temp"
    
    -- Crear directorio (silenciar error si ya existe)
    os.execute('mkdir "' .. work_dir .. '" > nul 2>&1') 
    
    -- Nombre constante para evitar errores de caracteres
    local temp_input_filename = "audio_proceso.wav"
    local temp_input_path = work_dir .. "\\" .. temp_input_filename
    
    reaper.ShowConsoleMsg("\nAI Stem Splitter by Oliver Tkach\n\n")
    reaper.ShowConsoleMsg("🔹 Copying to TEMP (Lua Binary): " .. work_dir .. "...\n")
    
    -- Copiar archivo usando LUA (Bypass total de CMD y sus problemas de encoding)
    local success, err_msg = copy_file_lua(file_path, temp_input_path)
    
    if not success then
        reaper.ShowMessageBox("Error copying file (Lua):\n" .. (err_msg or "Unknown") .. "\n\nSource: " .. file_path, "Fatal Error", 0)
        return
    end

    -- Crear BAT en la carpeta de trabajo
    local bat_path = work_dir .. "\\run_demucs.bat"
    
    local f = io.open(bat_path, "w")
    local model_name = "htdemucs_6s" 
    
    if f then
        f:write("@echo off\n")
        f:write("chcp 65001 > nul\n") -- UTF-8 por si acaso
        f:write("cd /d \"" .. work_dir .. "\"\n")
        f:write("echo 🤖 ANTIGRAVITY AI ENGINE\n")
        f:write("echo ------------------------\n")
        f:write('echo Processing: "' .. song_name .. '"\n')
        f:write("echo.\n")
        
        -- Ejecutar demucs sobre el archivo renombrado audio_proceso.wav
        f:write('python -m demucs.separate -n ' .. model_name .. ' "' .. temp_input_filename .. '" -o .\n')
        
        f:write("if %ERRORLEVEL% NEQ 0 (\n")
        f:write("    echo.\n")
        f:write("    echo ❌ CRITICAL ERROR:\n")
        f:write("    echo.\n")
        f:write("    pause\n")
        f:write("    exit /b %ERRORLEVEL%\n")
        f:write(")\n")
        f:write("echo.\n")
        f:write("echo ✅ Finished successfully.\n")
        f:write("exit 0\n")
        f:close()
    else
        reaper.ShowMessageBox("Could not create BAT script in:\n" .. work_dir, "Error", 0)
        return
    end

    local execute_cmd = 'cmd /C "' .. bat_path .. '"'
    
    -- Ejecutar
    local retval = os.execute(execute_cmd)
    
    os.remove(bat_path)
    os.remove(temp_input_path) -- Borrar input temporal
    
    -- 4. IMPORTAR RESULTADOS
    -- Estructura demucs: work_dir / model_name / audio_proceso / stem.wav
    -- El nombre de la carpeta es el del archivo input sin extension ("audio_proceso")
    local temp_stem_folder_name = "audio_proceso"
    
    local system_separator = "\\"
    local stems_dir = work_dir .. system_separator .. model_name .. system_separator .. temp_stem_folder_name
    
    -- Verify exact path exists. Lua file checking is manual.
    -- We try to find at least one stem to confirm success.
    local check_file = stems_dir .. system_separator .. "vocals.wav"
    -- Check mp3 if wav missing
    local file = io.open(check_file, "r")
    if not file then
        check_file = stems_dir .. system_separator .. "vocals.mp3"
        file = io.open(check_file, "r")
    end
    
    if file then
        file:close() -- It exists!
        
        reaper.ShowConsoleMsg("✅ Processing finished. Importing tracks...\n")
        
        reaper.Undo_BeginBlock()
        
        -- Create Mother Folder
        local num_tracks = reaper.GetNumTracks()
        reaper.InsertTrackAtIndex(num_tracks, true)
        local folder_tr = reaper.GetTrack(0, num_tracks)
        
        reaper.GetSetMediaTrackInfo_String(folder_tr, "P_NAME", "STEMS: " .. song_name, true)
        reaper.SetMediaTrackInfo_Value(folder_tr, "I_FOLDERDEPTH", 1) -- Start Folder
        
        -- Instruments to import
        local instruments = {"vocals", "drums", "bass", "guitar", "piano", "other"}
        
        reaper.Main_OnCommand(40297, 0) -- Unselect all tracks first
        
        for _, inst in ipairs(instruments) do
            local stem_path_wav = stems_dir .. system_separator .. inst .. ".wav"
            local stem_path_mp3 = stems_dir .. system_separator .. inst .. ".mp3"
            local final_path = nil
            
            -- Check existence
            local f = io.open(stem_path_wav, "r")
            if f then 
                f:close()
                final_path = stem_path_wav
            else
                f = io.open(stem_path_mp3, "r")
                if f then
                    f:close()
                    final_path = stem_path_mp3
                end
            end
            
            if final_path then
                -- Insert Track
                local tr_idx = reaper.GetNumTracks()
                reaper.InsertTrackAtIndex(tr_idx, true)
                local tr = reaper.GetTrack(0, tr_idx)
                
                -- Name Track
                reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", string.upper(inst), true)
                
                -- Select ONLY this track for InsertMedia
                reaper.SetOnlyTrackSelected(tr)
                reaper.SetEditCurPos(pos, false, false)
                
                -- Insert Media (Let Reaper handle length naturally)
                -- 0 = add to current track
                local success = reaper.InsertMedia(final_path, 0) 
                
                if success == 1 then
                    -- Rename the item to contain song name (User Request)
                    -- InsertMedia selects the new item typically
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
        local last_tr_idx = reaper.GetNumTracks() - 1
        local last_tr = reaper.GetTrack(0, last_tr_idx)
        -- Set folder depth to -1 (close 1 level)
        -- We get current depth just in case, but usually newly inserted tracks are 0
        reaper.SetMediaTrackInfo_Value(last_tr, "I_FOLDERDEPTH", -1)
        
        reaper.Undo_EndBlock("Import AI Stems", -1)
        reaper.UpdateArrange()
        reaper.ShowConsoleMsg("🚀 Done!\n")
        
    else
        reaper.ShowMessageBox("AI finished, but files not found.\nSearched path:\n" .. stems_dir, "AI Stem Splitter by Oliver Tkach", 0)
    end
end

main()
