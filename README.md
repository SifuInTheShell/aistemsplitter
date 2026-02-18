# 🤖 AI Stem Splitter by Oliver Tkach (Unified Version)

A professional ReaScript for **REAPER** that utilizes Artificial Intelligence (**Demucs**) to separate audio into 6 high-fidelity tracks directly within your project.

> **Note:** I'm primarily an **audio guy**, not a professional developer. This tool was born out of a personal workflow need and built using AI assistance (Antigravity). I'm sharing it so other producers can benefit from it!

## ✨ Features

* **6 Stems:** Separate audio into Vocals, Drums, Bass, Guitar, Piano, and Other.
* **Privacy:** Processes everything locally; no cloud uploads, 100% private.
* **Cross-Platform:** One script for Windows and Linux.
* **Automatic Organization:** Creates folders, names tracks, and aligns them perfectly.
* **Smart Fallback:** Now includes automatic MP3 fallback if WAV export is unavailable.

---

## 🛠️ Requirements

1. **Python 3.10+:** Download from [python.org](https://www.python.org/).
* **CRITICAL:** During installation, check the box **"Add Python to PATH"**.


2. **FFmpeg:** Essential for audio encoding.
* **Windows:** Install and add to System PATH.
* **Mac:** `brew install ffmpeg`.


3. **Libraries:** Run this in your terminal to avoid common errors:
`python -m pip install demucs soundfile==0.12.1 torchcodec`

---

## 🚀 Installation & Usage

1. **Download** the script you prefer:
* `AI Stem Splitter by Oliver Tkach - GUI.lua` (Recommended: Features a progress bar).
* `AI Stem Splitter by Oliver Tkach.lua` (Standard version).


2. **In REAPER:** Open **Action List (?) > New Action > Load ReaScript...** and select the file.
3. **Run:** Select an audio item, run the script, and wait for the AI to work its magic.
* *First run:* The script will download the AI models (approx. 2GB).



---

## 🤝 Community Collaboration

Since I'm not a coder, the community has been vital in making this script robust:

* **Project Lead:** Oliver Tkach (Audio/Workflow logic).
* **Major Contributor:** A huge thanks to **SifuInTheShell** for the professional refactoring, unifying cross-platform support, and implementing the smart fallback and logging systems.

---

## 🛠️ Troubleshooting (FAQ)

* **"Python not recognized":** You forgot to check "Add Python to PATH" during installation. Reinstall Python.
* **"TorchCodec required":** Run `pip install torchcodec` in your terminal.
* **Mac Permission Errors:** Ensure REAPER has **Full Disk Access** in System Settings > Privacy & Security.
* **NVIDIA vs CPU:** NVIDIA users will process in seconds via CUDA. Everyone else will use CPU (takes 3-7 minutes), but the **quality remains professional grade**.

---

## 🙌 Support the Project

If this script has improved your workflow, feel free to support its development!

📸 **Instagram:** [@olivertkachmusic](https://www.instagram.com/olivertkachmusic)
🎥 **YouTube:** [@olivertkachreactions](https://www.youtube.com/@olivertkachreactions)

If you'd like to buy me a coffee (or a "tecito" 🍵):
☕ **[Donate / Tecito](https://tecito.app/olivertkachmusic)**
