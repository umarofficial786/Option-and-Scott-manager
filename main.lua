require "import"
import "android.widget.*"
import "android.view.*"
import "java.io.File"
import "java.io.FileInputStream"
import "java.io.FileOutputStream"
import "java.io.RandomAccessFile"
import "android.media.MediaRecorder"
import "android.media.MediaPlayer"
import "android.media.MediaScannerConnection"
import "android.media.MediaExtractor"
import "android.media.MediaMuxer"
import "android.media.MediaFormat"
import "android.media.MediaCodec"
import "android.media.AudioManager"
import "android.media.AudioRecord"
import "android.media.AudioFormat"
import "android.net.Uri"
import "java.lang.String"
import "java.nio.ByteBuffer"
import "android.content.Intent"
import "android.content.Context"
import "android.content.ClipData"
import "android.content.DialogInterface"
import "android.content.pm.PackageManager"
import "android.provider.Settings"
import "android.os.Build"
import "android.os.Handler"
import "android.os.Looper"
import "android.media.audiofx.LoudnessEnhancer"
import "android.media.audiofx.NoiseSuppressor"
import "android.media.audiofx.AcousticEchoCanceler"
import "android.media.audiofx.AutomaticGainControl"

------------------------------------------------------------
-- Context resolution
------------------------------------------------------------
local ctx = this or service or activity

local function say(text)
    pcall(function() if service then service.speak(text) end end)
end

local function toast(msg)
    pcall(function() Toast.makeText(ctx, tostring(msg), Toast.LENGTH_SHORT).show() end)
end

local function safe(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            toast("Error: " .. tostring(err))
            say("An error happened")
        end
    end
end

-- Create a Java byte[] (luajava.newArray("byte", n) does NOT work on
-- this Lua version: it needs a Class object, not a string)
local function newBytes(n)
    local ok, arr = pcall(function()
        local JArray = luajava.bindClass("java.lang.reflect.Array")
        local ByteC = luajava.bindClass("java.lang.Byte")
        return JArray.newInstance(ByteC.TYPE, n)
    end)
    if ok and arr then return arr end
    local ok2, arr2 = pcall(function()
        return luajava.newArray(luajava.bindClass("java.lang.Byte").TYPE, n)
    end)
    if ok2 and arr2 then return arr2 end
    error("cannot create byte array: " .. tostring(arr) .. " | " .. tostring(arr2))
end

-- Global Variables
local EXT = ".m4a" -- MPEG_4 container + AAC = M4A
local tempFolder = "/storage/emulated/0/CallRecordings/Temp/"
local saveFolder = "/storage/emulated/0/CallRecordings/"
local SRC = MediaRecorder.AudioSource
local SRC_UNPROCESSED = 9
_G.rec_instance = _G.rec_instance or nil
_G.rec_source_used = _G.rec_source_used or nil
_G.rec_file_path = _G.rec_file_path or nil
_G.temp_file_path = _G.temp_file_path or nil
_G.rec_start_time = _G.rec_start_time or 0
_G.rec_paused_total = _G.rec_paused_total or 0
_G.rec_pause_started = _G.rec_pause_started or 0
_G.rec_monitor_token = _G.rec_monitor_token or 0
_G.rec_player = _G.rec_player or nil
_G.loudness_enhancer = _G.loudness_enhancer or nil
_G.noise_suppressor = _G.noise_suppressor or nil
_G.echo_canceler = _G.echo_canceler or nil
_G.auto_gain = _G.auto_gain or nil
_G.is_paused = false
_G.rec_is_recorder_paused = false
_G.rec_proc_mode = _G.rec_proc_mode or nil -- "call" | "mic" | "echo"
_G.rec_pcm_rate = _G.rec_pcm_rate or 44100
_G.last_rec_error = nil
_G.echo_busy = false
_G.update_prompt_open = false

-- Auto update settings. Raise the number below every time you publish
-- a new version on GitHub (1, 2, 3 ...). A phone with a lower number
-- will offer the update when the plugin is opened.
local APP_VERSION = 3
local UPDATE_NOTE = "UPDATED v3 - safer updates"
local UPDATE_URL = "https://raw.githubusercontent.com/umarofficial786/Audio-recorder/refs/heads/main/main.lua"

local monitorHandler = Handler(Looper.getMainLooper())

------------------------------------------------------------
-- Error log (CallRecordings/recorder_log.txt)
------------------------------------------------------------
local function logError(msg)
    pcall(function()
        local fos = FileOutputStream(saveFolder .. "recorder_log.txt", true)
        local line = os.date("%Y-%m-%d %H:%M:%S") .. "  " .. tostring(msg) .. "\n"
        fos.write(String(line).getBytes())
        fos.close()
    end)
end

------------------------------------------------------------
-- Folder & file helpers
------------------------------------------------------------
function initFolders()
    pcall(function()
        local tempDir = File(tempFolder)
        if not tempDir.exists() then tempDir.mkdirs() end
        local saveDir = File(saveFolder)
        if not saveDir.exists() then saveDir.mkdirs() end
    end)
end

-- Only checks that the folders exist (Android 11+ silently fails
-- to create them without all-files access)
function storageReady()
    initFolders()
    local ok, ready = pcall(function()
        return File(saveFolder).exists() and File(tempFolder).exists()
    end)
    return ok and ready
end

function requestStorageAccessScreen()
    say("Storage access is required. Please allow all files access")
    toast("Please allow 'All files access' for this app")
    pcall(function()
        local pkg = ctx.getPackageName()
        local i
        if Build.VERSION.SDK_INT >= 30 then
            i = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
        else
            i = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        end
        i.setData(Uri.parse("package:" .. pkg))
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ctx.startActivity(i)
    end)
end

function cleanupOldTempFiles()
    pcall(function()
        local dir = File(tempFolder)
        if not dir.exists() then return end
        local files = dir.listFiles()
        if not files then return end
        local now = os.time() * 1000
        for i = 0, #files - 1 do
            local f = files[i]
            pcall(function()
                if (now - f.lastModified()) > (24 * 60 * 60 * 1000) then
                    f.delete()
                end
            end)
        end
    end)
end

function scanFile(filePath)
    pcall(function()
        local paths = String[1]
        paths[0] = filePath
        MediaScannerConnection.scanFile(ctx, paths, nil, nil)
    end)
end

function getFileSizeFormatted(filePath)
    if not filePath then return "0 KB" end
    local status, sizeStr = pcall(function()
        local file = File(filePath)
        if file.exists() then
            local sizeInKb = file.length() / 1024
            if sizeInKb > 1024 then
                return string.format("%.2f MB", sizeInKb / 1024)
            else
                return string.format("%.2f KB", sizeInKb)
            end
        end
        return "0 KB"
    end)
    return status and sizeStr or "0 KB"
end

function moveFile(srcPath, dstPath)
    local ok = pcall(function()
        local src = File(srcPath)
        local dst = File(dstPath)
        if src.renameTo(dst) then return end
        local inStream = FileInputStream(src)
        local outStream = FileOutputStream(dst)
        local javaBuf = newBytes(65536)
        while true do
            local n = inStream.read(javaBuf)
            if n <= 0 then break end
            outStream.write(javaBuf, 0, n)
        end
        inStream.close()
        outStream.close()
        src.delete()
    end)
    return ok and File(dstPath).exists()
end

local function isInTemp(path)
    return path ~= nil and string.find(path, "/Temp/", 1, true) ~= nil
end

-- Generic yes/no dialog
local function askConfirm(message, yesText, noText, onYes)
    local layout = {
        LinearLayout, orientation="vertical", padding="20dp",
        {TextView, text=message, textSize="16sp", gravity="center", layout_marginBottom="20dp"},
        {Button, id="btnAskYes", text=yesText, layout_width="fill", height="45dp", layout_marginBottom="10dp"},
        {Button, id="btnAskNo", text=noText, layout_width="fill", height="45dp"}
    }
    local dlg = LuaDialog(ctx).setView(loadlayout(layout))
    btnAskYes.onClick = safe(function()
        dlg.dismiss()
        onYes()
    end)
    btnAskNo.onClick = safe(function() dlg.dismiss() end)
    dlg.show()
end

-- Error window that stays on screen, with selectable text and a
-- "Copy text" button (toasts disappear too fast to read)
local function showErrorDialog(title, msg)
    pcall(function()
        local layout = {
            LinearLayout, orientation="vertical", padding="20dp",
            {TextView, text=title, textSize="18sp", gravity="center", layout_marginBottom="10dp"},
            {TextView, id="lblErrText", text=tostring(msg), textSize="14sp", layout_marginBottom="15dp"},
            {Button, id="btnErrCopy", text="Copy text", layout_width="fill", height="45dp", layout_marginBottom="8dp"},
            {Button, id="btnErrClose", text="Close", layout_width="fill", height="45dp"}
        }
        local d = LuaDialog(ctx).setView(loadlayout(layout))
        pcall(function() lblErrText.setTextIsSelectable(true) end)
        btnErrCopy.onClick = safe(function()
            local cm = ctx.getSystemService(Context.CLIPBOARD_SERVICE)
            cm.setPrimaryClip(ClipData.newPlainText("error", tostring(msg)))
            toast("Text copied")
        end)
        btnErrClose.onClick = safe(function() d.dismiss() end)
        d.show()
    end)
end

------------------------------------------------------------
-- Permissions
------------------------------------------------------------
function hasRecordPermission()
    local ok, granted = pcall(function()
        if Build.VERSION.SDK_INT < 23 then return true end
        return ctx.checkSelfPermission("android.permission.RECORD_AUDIO") == PackageManager.PERMISSION_GRANTED
    end)
    if ok then return granted end
    return true
end

function requestRecordPermissionScreen()
    say("Microphone permission is required. Please allow it from app settings")
    toast("Please allow Microphone permission for this app")
    pcall(function()
        local pkg = ctx.getPackageName()
        local i = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        i.setData(Uri.parse("package:" .. pkg))
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ctx.startActivity(i)
    end)
end

-- Call mode: this NEVER turns the speaker on or off. It only raises
-- the call volume to maximum if the speaker is already on, so the
-- phone's microphone can pick up the other person louder.
local function prepareCallAudio()
    pcall(function()
        local am = ctx.getSystemService(Context.AUDIO_SERVICE)
        local spk = false
        pcall(function() spk = am.isSpeakerphoneOn() end)
        if spk then
            pcall(function()
                am.setStreamVolume(AudioManager.STREAM_VOICE_CALL,
                    am.getStreamMaxVolume(AudioManager.STREAM_VOICE_CALL), 0)
            end)
        end
    end)
end

------------------------------------------------------------
-- Release recorder + effects (also stops the silence monitor)
------------------------------------------------------------
function releaseRecorderResources()
    _G.rec_monitor_token = (_G.rec_monitor_token or 0) + 1 -- cancels any running monitor
    pcall(function()
        if _G.noise_suppressor then
            pcall(function() _G.noise_suppressor.setEnabled(false) end)
            pcall(function() _G.noise_suppressor.release() end)
            _G.noise_suppressor = nil
        end
    end)
    pcall(function()
        if _G.echo_canceler then
            pcall(function() _G.echo_canceler.release() end)
            _G.echo_canceler = nil
        end
    end)
    pcall(function()
        if _G.auto_gain then
            pcall(function() _G.auto_gain.release() end)
            _G.auto_gain = nil
        end
    end)
    pcall(function()
        if _G.rec_instance then
            pcall(function() _G.rec_instance.stop() end)
            pcall(function() _G.rec_instance.release() end)
            _G.rec_instance = nil
        end
    end)
    _G.rec_is_recorder_paused = false
end

------------------------------------------------------------
-- Recording engine
------------------------------------------------------------
local CLASSIC_PROFILES = {
    {rate = 22050, bitrate = 64000},
    {rate = 44100, bitrate = 128000, mono = true}
}
local HQ_PROFILES = {
    {rate = 44100, bitrate = 128000, mono = true},
    {rate = 22050, bitrate = 64000}
}

-- Each entry is one way to record. Entries without "kind" use
-- MediaRecorder (m4a). Entries with kind="pcm" use AudioRecord
-- (raw audio, cleaned after Stop and saved as wav). If an entry
-- records only silence for 3 seconds, the script automatically
-- moves to the next entry.
local CALL_SOURCES = {
    {kind = "pcm", src = SRC.VOICE_COMMUNICATION, rate = 16000, label = "Call Mode"},
    {kind = "pcm", src = SRC.VOICE_CALL,          rate = 16000, label = "Call Mode (Direct Call)"},
    {kind = "pcm", src = SRC.VOICE_RECOGNITION,   rate = 16000, label = "Call Mode (Recognition)"},
    {kind = "pcm", src = SRC.MIC,                 rate = 16000, label = "Call Mode (Mic)"},
    {kind = "pcm", src = SRC_UNPROCESSED,         rate = 16000, label = "Call Mode (Unprocessed)"},
    {src = SRC.VOICE_COMMUNICATION, label = "Call Mode (Classic)", profiles = CLASSIC_PROFILES},
    {src = SRC.VOICE_CALL,          label = "Call Mode (Classic Direct)", profiles = CLASSIC_PROFILES},
    {src = SRC.VOICE_RECOGNITION,   label = "Call Mode (Classic Recognition)", profiles = CLASSIC_PROFILES},
    {src = SRC.MIC,                 label = "Call Mode (Classic Mic)", profiles = CLASSIC_PROFILES},
    {src = SRC.CAMCORDER,           label = "Call Mode (Classic Camcorder)", profiles = CLASSIC_PROFILES}
}
local MIC_SOURCES = {
    {kind = "pcm", src = SRC.MIC, rate = 48000, label = "Mic Mode"},
    {kind = "pcm", src = SRC.VOICE_RECOGNITION, rate = 48000, label = "Mic Mode (Recognition)"},
    {src = SRC.MIC, label = "Mic Mode (Compatibility)", profiles = HQ_PROFILES}
}
local ECHO_SOURCES = {
    {kind = "pcm", src = SRC.MIC, rate = 22050, label = "Echo Mode"},
    {kind = "pcm", src = SRC.VOICE_RECOGNITION, rate = 22050, label = "Echo Mode (Recognition)"},
    {src = SRC.MIC, label = "Echo Mode (Compatibility)", profiles = HQ_PROFILES}
}

-- Effects on the live audio session:
--   noise suppressor  ON  (helps against constant background noise)
--   echo canceler     OFF (it removes the other person's voice that
--                          comes out of the speaker - the main reason
--                          the other side sounds quiet)
--   auto gain         OFF (this script raises the volume itself, after
--                          the noise has been removed)
local function attachEffects()
    local sessionId = nil
    pcall(function() sessionId = _G.rec_instance.getAudioSessionId() end)
    if not sessionId then return end
    pcall(function()
        if NoiseSuppressor.isAvailable() then
            _G.noise_suppressor = NoiseSuppressor.create(sessionId)
            if _G.noise_suppressor then _G.noise_suppressor.setEnabled(true) end
        end
    end)
    pcall(function()
        if AcousticEchoCanceler.isAvailable() then
            _G.echo_canceler = AcousticEchoCanceler.create(sessionId)
            if _G.echo_canceler then _G.echo_canceler.setEnabled(false) end
        end
    end)
    pcall(function()
        if AutomaticGainControl.isAvailable() then
            _G.auto_gain = AutomaticGainControl.create(sessionId)
            if _G.auto_gain then _G.auto_gain.setEnabled(false) end
        end
    end)
end

------------------------------------------------------------
-- PCM recorder (AudioRecord). Exposes the same methods as
-- MediaRecorder (pause/resume/stop/release/getMaxAmplitude), so the
-- rest of the script works unchanged. Reading happens in small
-- slices on the UI handler (no extra threads).
------------------------------------------------------------
local function createPcmRecorder(path, rate, audioSource)
    local CH_CFG = AudioFormat.CHANNEL_IN_MONO
    local ENC = AudioFormat.ENCODING_PCM_16BIT
    local minBuf = AudioRecord.getMinBufferSize(rate, CH_CFG, ENC)
    if not minBuf or minBuf <= 0 then
        error("rate " .. rate .. " not supported (minBuf=" .. tostring(minBuf) .. ")")
    end
    local bufSize = math.max(minBuf * 4, rate * 4)

    -- way 1: normal constructor
    local ar = nil
    local ok1, e1 = pcall(function()
        ar = AudioRecord(audioSource, rate, CH_CFG, ENC, bufSize)
    end)
    local bad = (not ok1) or (ar == nil) or (ar.getState() ~= AudioRecord.STATE_INITIALIZED)

    -- way 2: Builder (Android 6+)
    local e2 = nil
    if bad then
        if ar then pcall(function() ar.release() end) end
        ar = nil
        local ok2, err2 = pcall(function()
            local ABuilder = luajava.bindClass("android.media.AudioRecord$Builder")
            local FBuilder = luajava.bindClass("android.media.AudioFormat$Builder")
            local fmt = FBuilder().setEncoding(ENC).setSampleRate(rate).setChannelMask(CH_CFG).build()
            local b = ABuilder()
            b.setAudioSource(audioSource)
            b.setAudioFormat(fmt)
            b.setBufferSizeInBytes(bufSize)
            ar = b.build()
        end)
        if not ok2 then e2 = err2 end
        bad = (not ok2) or (ar == nil) or (ar.getState() ~= AudioRecord.STATE_INITIALIZED)
    end
    if bad then
        if ar then pcall(function() ar.release() end) end
        error("AudioRecord failed (source " .. tostring(audioSource) .. ", " .. rate .. " Hz). constructor: "
            .. tostring(e1) .. " | builder: " .. tostring(e2))
    end

    -- buffer + file (release the AudioRecord if anything here fails)
    local chunk, out
    local okB, eB = pcall(function()
        chunk = newBytes(16384)
        out = FileOutputStream(path)
    end)
    if not okB then
        pcall(function() ar.release() end)
        error("could not prepare buffer/file: " .. tostring(eB))
    end

    local handler = Handler(Looper.getMainLooper())
    local obj = {paused = false, running = false, closed = false, peak = 0}
    local nonBlocking = Build.VERSION.SDK_INT >= 23

    local function drain()
        for _ = 1, 16 do
            local n
            if nonBlocking then
                n = ar.read(chunk, 0, 16384, AudioRecord.READ_NON_BLOCKING)
            else
                n = ar.read(chunk, 0, 2048)
            end
            if n and n > 0 then
                -- sparse peak check (cheap) used by the silence monitor
                local i = 0
                while i + 1 < n do
                    local lo = chunk[i]
                    if lo < 0 then lo = lo + 256 end
                    local v = chunk[i + 1] * 256 + lo
                    if v < 0 then v = -v end
                    if v > obj.peak then obj.peak = v end
                    i = i + 128
                end
                if not obj.paused then out.write(chunk, 0, n) end
                if not nonBlocking then break end
            else
                break
            end
        end
    end

    local tick
    tick = Runnable({
        run = function()
            if not obj.running then return end
            pcall(drain)
            handler.postDelayed(tick, 25)
        end
    })

    obj.pause = function() obj.paused = true end
    obj.resume = function() obj.paused = false end
    obj.getMaxAmplitude = function()
        local p = obj.peak
        obj.peak = 0
        return p
    end
    obj.getAudioSessionId = function() return ar.getAudioSessionId() end
    obj.stop = function()
        if obj.closed then return end
        obj.running = false
        pcall(drain)
        pcall(function() ar.stop() end)
        pcall(function() out.flush() end)
        pcall(function() out.close() end)
        obj.closed = true
    end
    obj.release = function()
        obj.running = false
        pcall(function() ar.release() end)
        if not obj.closed then
            pcall(function() out.close() end)
            obj.closed = true
        end
    end

    ar.startRecording()
    obj.running = true
    handler.post(tick)
    return obj
end

local function tryPcmEntry(entry)
    local rates = {entry.rate or 44100, 44100, 16000, 48000}
    local seen = {}
    local lastErr = nil
    for _, rate in ipairs(rates) do
        if not seen[rate] then
            seen[rate] = true
            _G.temp_file_path = tempFolder .. "Temp_" .. os.time() .. ".pcm"
            _G.rec_file_path = _G.temp_file_path
            local ok, res = pcall(createPcmRecorder, _G.temp_file_path, rate, entry.src)
            if ok then
                _G.rec_instance = res
                _G.rec_pcm_rate = rate
                attachEffects()
                return true
            end
            lastErr = tostring(res)
            pcall(function() File(_G.temp_file_path).delete() end)
        end
    end
    _G.last_rec_error = lastErr
    logError("PCM failed for [" .. tostring(entry.label) .. "]: " .. tostring(lastErr))
    return false
end

local function tryMediaRecorderEntry(entry)
    local profiles = entry.profiles or HQ_PROFILES
    for _, q in ipairs(profiles) do
        _G.temp_file_path = tempFolder .. "Temp_" .. os.time() .. EXT
        _G.rec_file_path = _G.temp_file_path

        local ok, e = pcall(function()
            _G.rec_instance = MediaRecorder()
            _G.rec_instance.setAudioSource(entry.src)
            _G.rec_instance.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            _G.rec_instance.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            if q.mono then
                pcall(function() _G.rec_instance.setAudioChannels(1) end)
            end
            _G.rec_instance.setAudioEncodingBitRate(q.bitrate)
            _G.rec_instance.setAudioSamplingRate(q.rate)
            _G.rec_instance.setOutputFile(_G.temp_file_path)

            pcall(function()
                _G.rec_instance.setOnErrorListener(MediaRecorder.OnErrorListener{
                    onError = function(mr, what, extra)
                        releaseRecorderResources()
                        say("Recording stopped due to a device error")
                        toast("Recording stopped: device audio error")
                    end
                })
            end)

            _G.rec_instance.prepare()
            _G.rec_instance.start()
            attachEffects()
        end)

        if ok then return true end
        _G.last_rec_error = tostring(e)
        logError("MediaRecorder failed [" .. tostring(entry.label) .. ", " .. q.rate .. " Hz]: " .. tostring(e))
        releaseRecorderResources()
        pcall(function() File(_G.temp_file_path).delete() end)
    end
    return false
end

local function tryOneSource(entry)
    if entry.kind == "pcm" then
        return tryPcmEntry(entry)
    end
    return tryMediaRecorderEntry(entry)
end

local startFromIndex -- forward declaration

-- Silence monitor: if the current source records pure silence for
-- 3 seconds, switch to the next source in the list automatically.
local function startSilenceMonitor(sourceList, idx, modeLabel)
    local token = (_G.rec_monitor_token or 0) + 1
    _G.rec_monitor_token = token
    local zeros = 0
    local r
    r = Runnable({
        run = function()
            if _G.rec_monitor_token ~= token or not _G.rec_instance then return end
            if not _G.rec_is_recorder_paused then
                local amp = 0
                pcall(function() amp = _G.rec_instance.getMaxAmplitude() end)
                if amp and amp > 0 then
                    return -- real audio confirmed, monitoring no longer needed
                end
                zeros = zeros + 1
                if zeros >= 3 then
                    if idx < #sourceList then
                        logError("Silence on [" .. tostring(sourceList[idx].label) .. "], switching")
                        releaseRecorderResources()
                        pcall(function() File(_G.temp_file_path).delete() end)
                        if startFromIndex(sourceList, idx + 1, modeLabel) then
                            toast("Silence detected, switched to: " .. tostring(_G.rec_source_used))
                        else
                            say("Recording Error. No audio source worked")
                            showErrorDialog("Recording failed", "Every audio source failed or was silent. Last error: " .. tostring(_G.last_rec_error))
                        end
                    else
                        toast("Warning: only silence is being recorded")
                        say("Warning. Only silence is being recorded")
                    end
                    return
                end
            end
            monitorHandler.postDelayed(r, 1000)
        end
    })
    monitorHandler.postDelayed(r, 1000)
end

startFromIndex = function(sourceList, startIdx, modeLabel)
    for i = startIdx, #sourceList do
        local entry = sourceList[i]
        if tryOneSource(entry) then
            _G.rec_start_time = os.time()
            _G.rec_paused_total = 0
            _G.rec_pause_started = 0
            _G.rec_source_used = entry.label
            say("Recording Started: " .. entry.label)
            startSilenceMonitor(sourceList, i, modeLabel)
            return true
        end
    end
    return false
end

function startRecording(sourceList, modeLabel, procMode)
    _G.rec_proc_mode = procMode
    _G.last_rec_error = nil
    if not storageReady() then
        requestStorageAccessScreen()
        return
    end
    cleanupOldTempFiles()
    releaseRecorderResources()

    if not hasRecordPermission() then
        requestRecordPermissionScreen()
        return
    end

    if procMode == "call" then prepareCallAudio() end

    if not startFromIndex(sourceList, 1, modeLabel) then
        local why = ""
        if _G.last_rec_error then why = "\n\nDetails: " .. tostring(_G.last_rec_error) end
        say("Recording Error. This phone does not allow recording in " .. modeLabel)
        showErrorDialog("Recording failed", "This phone did not allow recording in " .. modeLabel .. why)
    end
end

function showMenu()
    local layout = {
        LinearLayout, orientation="vertical", padding="20dp",
        {TextView, text="Audio Recorder Pro X  (v" .. APP_VERSION .. ")", textSize="20sp", gravity="center", layout_marginBottom="5dp"},
        {TextView, text=UPDATE_NOTE, textSize="14sp", gravity="center", layout_marginBottom="15dp"},
        {Button, id="btnCall", text="Speaker / Call Recording", layout_width="fill", height="60dp", layout_marginBottom="10dp"},
        {Button, id="btnMic", text="Microphone (Zero Noise Pro)", layout_width="fill", height="60dp", layout_marginBottom="10dp"},
        {Button, id="btnEcho", text="Echo Recording", layout_width="fill", height="60dp", layout_marginBottom="10dp"},
        {Button, id="btnList", text="My Recordings", layout_width="fill", height="60dp", layout_marginBottom="10dp"},
        {Button, id="btnUpdate", text="Check for Update", layout_width="fill", height="60dp", layout_marginBottom="10dp"},
        {Button, id="btnCancel", text="Cancel", layout_width="fill", height="50dp"}
    }

    local d = LuaDialog(ctx).setView(loadlayout(layout))

    btnCall.onClick = safe(function()
        d.dismiss()
        startRecording(CALL_SOURCES, "Call Mode", "call")
    end)

    btnMic.onClick = safe(function()
        d.dismiss()
        startRecording(MIC_SOURCES, "Mic Mode", "mic")
    end)

    btnEcho.onClick = safe(function()
        d.dismiss()
        startRecording(ECHO_SOURCES, "Echo Mode", "echo")
    end)

    btnList.onClick = safe(function()
        d.dismiss()
        showRecordingsList()
    end)

    btnUpdate.onClick = safe(function()
        d.dismiss()
        checkForUpdate(true)
    end)

    btnCancel.onClick = safe(function() d.dismiss() end)
    d.show()
end

------------------------------------------------------------
-- In-progress controls: Pause / Resume / Stop / Cancel
------------------------------------------------------------
local function elapsedSeconds()
    local now = os.time()
    local paused = _G.rec_paused_total or 0
    if _G.rec_is_recorder_paused then
        paused = paused + (now - (_G.rec_pause_started or now))
    end
    local e = now - _G.rec_start_time - paused
    if e < 0 then e = 0 end
    return e
end

function discardRecording()
    releaseRecorderResources()
    pcall(function()
        if _G.rec_file_path and File(_G.rec_file_path).exists() then
            File(_G.rec_file_path).delete()
        end
    end)
    _G.rec_file_path = nil
    _G.temp_file_path = nil
    _G.rec_proc_mode = nil
    say("Recording cancelled")
end

-- Running the script while recording PAUSES it immediately and shows
-- Resume / Stop & Save / Discard. Running it again while paused just
-- shows the same dialog.
function showPausedDialog()
    if not _G.rec_instance then
        showMenu()
        return
    end

    if not _G.rec_is_recorder_paused then
        local ok = pcall(function() _G.rec_instance.pause() end)
        if not ok then
            toast("This phone cannot pause recording (needs Android 7+)")
            return
        end
        _G.rec_is_recorder_paused = true
        _G.rec_pause_started = os.time()
        say("Paused")
    end

    local layout = {
        LinearLayout, orientation="vertical", padding="20dp",
        {TextView, id="lblStatus", text="Paused", textSize="18sp", gravity="center", layout_marginBottom="5dp"},
        {TextView, id="lblTimer", text="00:00", textSize="24sp", gravity="center", layout_marginBottom="15dp"},
        {Button, id="btnResume", text="Resume", layout_width="fill", height="55dp", layout_marginBottom="10dp"},
        {Button, id="btnStop", text="Stop & Save", layout_width="fill", height="50dp", layout_marginBottom="10dp"},
        {Button, id="btnCancelRec", text="Cancel & Discard", layout_width="fill", height="50dp"}
    }

    local d = LuaDialog(ctx).setView(loadlayout(layout))

    local e = elapsedSeconds()
    lblTimer.setText(string.format("%02d:%02d", math.floor(e / 60), e % 60))

    btnResume.onClick = safe(function()
        if not _G.rec_instance then d.dismiss() return end
        local ok = pcall(function() _G.rec_instance.resume() end)
        if ok then
            _G.rec_paused_total = (_G.rec_paused_total or 0) + (os.time() - _G.rec_pause_started)
            _G.rec_is_recorder_paused = false
            d.dismiss()
            say("Resumed")
        else
            toast("Could not resume recording")
        end
    end)

    btnStop.onClick = safe(function()
        d.dismiss()
        stopRecording()
    end)

    btnCancelRec.onClick = safe(function()
        askConfirm("Discard this recording?", "Discard", "Keep", function()
            d.dismiss()
            discardRecording()
        end)
    end)

    d.show()
end

------------------------------------------------------------
-- WAV helpers
------------------------------------------------------------
local function wavHeader(dataLen, rate, ch)
    local h = newBytes(44)
    local function sb(i, v)
        v = math.floor(v) % 256
        if v > 127 then v = v - 256 end
        h[i] = v
    end
    local function str(i, t)
        for k = 1, #t do sb(i + k - 1, string.byte(t, k)) end
    end
    local function i32(i, v)
        for k = 0, 3 do sb(i + k, math.floor(v / (256 ^ k)) % 256) end
    end
    local function i16(i, v)
        sb(i, v % 256)
        sb(i + 1, math.floor(v / 256) % 256)
    end
    str(0, "RIFF"); i32(4, 36 + dataLen); str(8, "WAVE")
    str(12, "fmt "); i32(16, 16); i16(20, 1); i16(22, ch)
    i32(24, rate); i32(28, rate * ch * 2); i16(32, ch * 2); i16(34, 16)
    str(36, "data"); i32(40, dataLen)
    return h
end

-- Wrap raw PCM into a WAV file without any processing
local function rawToWav(srcPath, dstPath, rate, ch)
    local ok = pcall(function()
        local len = File(srcPath).length()
        local ins = FileInputStream(srcPath)
        local outs = FileOutputStream(dstPath)
        outs.write(wavHeader(len, rate, ch))
        local b = newBytes(65536)
        while true do
            local n = ins.read(b)
            if n == nil or n <= 0 then break end
            outs.write(b, 0, n)
        end
        ins.close()
        outs.close()
    end)
    if not ok then pcall(function() File(dstPath).delete() end) end
    return ok and File(dstPath).exists()
end

------------------------------------------------------------
-- FFT (radix-2, in place, tables precomputed once)
------------------------------------------------------------
local function makeFFT(N)
    local bits = 0
    local t = 1
    while t < N do
        t = t * 2
        bits = bits + 1
    end
    local rev, cosT, sinT = {}, {}, {}
    for i = 0, N - 1 do
        local r, x = 0, i
        for _ = 1, bits do
            r = r * 2 + (x % 2)
            x = math.floor(x / 2)
        end
        rev[i] = r
    end
    for i = 0, math.floor(N / 2) - 1 do
        local ang = 2 * math.pi * i / N
        cosT[i] = math.cos(ang)
        sinT[i] = -math.sin(ang)
    end
    return function(re, im)
        for i = 0, N - 1 do
            local j = rev[i]
            if j > i then
                re[i], re[j] = re[j], re[i]
                im[i], im[j] = im[j], im[i]
            end
        end
        local half = 1
        while half < N do
            local size = half * 2
            local step = math.floor(N / size)
            for start = 0, N - 1, size do
                local k = 0
                for j = start, start + half - 1 do
                    local l = j + half
                    local wr, wi = cosT[k], sinT[k]
                    local rl, il = re[l], im[l]
                    local tr = rl * wr - il * wi
                    local ti = rl * wi + il * wr
                    local rj, ij = re[j], im[j]
                    re[l] = rj - tr
                    im[l] = ij - ti
                    re[j] = rj + tr
                    im[j] = ij + ti
                    k = k + step
                end
            end
            half = size
        end
    end
end

------------------------------------------------------------
-- AUDIO PROCESSING (runs after Stop for every recording mode)
-- Signal chain:
--   1. high-pass filter 130 Hz (fan / wind / handling rumble)
--   2. spectral noise reduction: the noise level of every
--      frequency band is learned automatically (minimum tracking)
--      and subtracted (strong over-subtraction); in call mode the
--      hiss above 4.2 kHz is also reduced
--   3. noise gate: when nobody is speaking the sound is pushed down
--   4. smooth automatic volume (quiet voices boosted) + limiter
--   5. mode "echo" only: 300 ms echo (45% feedback) + 2 s tail
-- Runs in small slices on the UI handler (phone never freezes),
-- progress dialog with Cancel. If anything fails the recording is
-- saved UNPROCESSED and an error window (with Copy) is shown.
------------------------------------------------------------
local PROC_LABEL = {call = "Call", mic = "Mic", echo = "Echo"}
-- maxg = strongest volume boost, bias = noise removal strength
-- (higher = quieter noise, but too high sounds watery),
-- target = loudness target for speech, lp = hiss cut-off in Hz
local PROC_CFG = {
    call = {maxg = 16, bias = 3.2, target = 3000, lp = 4200},
    mic  = {maxg = 8,  bias = 2.8, target = 2800},
    echo = {maxg = 6,  bias = 3.0, target = 2800}
}

function startProcessing(srcPath, mode)
    _G.rec_proc_mode = nil
    _G.echo_busy = true

    local cfg = PROC_CFG[mode] or PROC_CFG.call
    local label = PROC_LABEL[mode] or "Audio"
    local isPcm = string.find(string.lower(srcPath), "%.pcm$") ~= nil
    local RATE, CH = _G.rec_pcm_rate or 44100, 1
    local outPath = saveFolder .. label .. "_" .. os.time() .. ".wav"
    local inStream, outStream, extractor, codec
    local total = 0
    pcall(function() total = File(srcPath).length() end)
    local readBytes, dataLen = 0, 0
    local durationUs, lastTime = 0, 0
    local finished, cancelled = false, false
    local outputDone = false
    local inputDone = false
    local flushed = false
    local tailLeft = 0
    local dlg = nil

    local function cleanupAll()
        pcall(function() if codec then codec.stop() end end)
        pcall(function() if codec then codec.release() end end)
        pcall(function() if extractor then extractor.release() end end)
        pcall(function() if inStream then inStream.close() end end)
        pcall(function() if outStream then outStream.close() end end)
        codec, extractor, inStream, outStream = nil, nil, nil, nil
    end

    local function closeDialog()
        if dlg then pcall(function() dlg.dismiss() end) end
    end

    local function finishWith(path, msg, isErr)
        _G.echo_busy = false
        closeDialog()
        if isInTemp(srcPath) and path ~= srcPath then
            pcall(function() File(srcPath).delete() end)
        end
        _G.rec_file_path = path
        _G.temp_file_path = nil
        scanFile(path)
        logError(msg)
        toast(msg)
        if isErr then say(label .. " problem. See the error window") else say(msg) end
        showResult()
        if isErr then showErrorDialog(label .. " problem", msg) end
    end

    -- failure/cancel: keep the recording UNPROCESSED
    local function fallbackDry(msg, isErr)
        cleanupAll()
        pcall(function() File(outPath).delete() end)
        if isPcm then
            local dryPath = saveFolder .. label .. "_" .. os.time() .. "_unprocessed.wav"
            if rawToWav(srcPath, dryPath, RATE, CH) then
                finishWith(dryPath, msg .. " (saved unprocessed)", isErr)
                return
            end
        else
            local dryPath = saveFolder .. label .. "_" .. os.time() .. "_unprocessed" .. EXT
            if moveFile(srcPath, dryPath) then
                finishWith(dryPath, msg .. " (saved unprocessed)", isErr)
                return
            end
        end
        -- last resort: keep the temp file as it is
        _G.echo_busy = false
        closeDialog()
        logError(msg .. " (original kept in Temp folder)")
        showResult()
        showErrorDialog(label .. " problem", msg .. " (original kept in Temp folder)")
    end

    -- open files / set up decoder (the stage is reported on failure)
    local stage = "start"
    local ok, err = pcall(function()
        stage = "create output file"
        outStream = FileOutputStream(outPath)
        outStream.write(newBytes(44)) -- header placeholder

        if isPcm then
            stage = "open raw audio file"
            inStream = FileInputStream(srcPath)
        else
            stage = "open recording (extractor)"
            extractor = MediaExtractor()
            extractor.setDataSource(srcPath)
            local trackIndex, format, mime = -1, nil, nil
            stage = "find audio track"
            for i = 0, extractor.getTrackCount() - 1 do
                local f = extractor.getTrackFormat(i)
                local m = f.getString(MediaFormat.KEY_MIME)
                if m and string.find(m, "audio/", 1, true) then
                    trackIndex, format, mime = i, f, m
                    break
                end
            end
            if trackIndex < 0 then error("No audio track found") end
            stage = "read audio format"
            RATE = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            CH = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            if format.containsKey(MediaFormat.KEY_DURATION) then
                durationUs = format.getLong(MediaFormat.KEY_DURATION)
            end
            extractor.selectTrack(trackIndex)
            stage = "create decoder"
            codec = MediaCodec.createDecoderByType(mime)
            stage = "configure decoder"
            local okc, ec = pcall(function() codec.configure(format, nil, nil, 0) end)
            if not okc then
                local okc2, ec2 = pcall(function() codec.configure(format, nil, 0, nil) end)
                if not okc2 then error(tostring(ec) .. " | " .. tostring(ec2)) end
            end
            stage = "start decoder"
            codec.start()
        end
    end)
    if not ok then
        fallbackDry(label .. " setup failed at [" .. stage .. "]: " .. tostring(err), true)
        return
    end

    local READ_N = 4096
    local buf, zbuf
    local okBuf, errBuf = pcall(function()
        buf = newBytes(READ_N)
        zbuf = newBytes(READ_N)
    end)
    if not okBuf then
        fallbackDry(label .. " setup failed at [buffer]: " .. tostring(errBuf), true)
        return
    end

    ----------------------------------------------------------
    -- engine state
    ----------------------------------------------------------
    local useNR = (CH == 1) -- noise reduction needs mono audio
    local N = (RATE >= 32000) and 1024 or 512
    local H = math.floor(N / 2)
    local K = H + 1
    local MAXG = cfg.maxg
    local TARGET = cfg.target
    local BIAS = cfg.bias
    local GMIN = 0.02
    local CUTBIN = K
    if cfg.lp then CUTBIN = math.floor(cfg.lp / RATE * N) end
    local HFG = 0.3 -- extra reduction of bins above the hiss cut-off
    local fps = RATE / H
    local LEAK = 1.12 ^ (1 / fps) -- noise floor may rise at most 12% per second
    local FB = 0.45
    local L = math.floor(0.30 * RATE) * CH
    local ring = {}
    local pos = 0
    if mode == "echo" then
        for i = 0, L - 1 do ring[i] = 0 end
    end

    local fft, w, xr, xi, Ps, Nn, Gs, Graw, prev, blk, outTbl, olap, obuf
    local hb0, hb1, hb2, ha1, ha2 = 0, 0, 0, 0, 0
    local hx1, hx2, hy1, hy2 = 0, 0, 0, 0
    local bi, fc = 0, 0
    local skipFirst = true
    local gcur, gAgc = 1.0, 1.0

    if useNR then
        local okN, eN = pcall(function()
            fft = makeFFT(N)
            w, xr, xi, Ps, Nn, Gs, Graw = {}, {}, {}, {}, {}, {}, {}
            prev, blk, outTbl, olap = {}, {}, {}, {}
            for i = 0, N - 1 do
                w[i] = math.sin(math.pi * (i + 0.5) / N)
                xr[i] = 0
                xi[i] = 0
            end
            for k = 0, K - 1 do
                Ps[k] = 0
                Nn[k] = 1e15
                Gs[k] = 1
                Graw[k] = 1
            end
            for i = 0, H - 1 do
                prev[i] = 0
                blk[i] = 0
                outTbl[i] = 0
                olap[i] = 0
            end
            obuf = newBytes(H * 2)
            -- 2nd order Butterworth high-pass, 130 Hz
            local w0 = 2 * math.pi * 130 / RATE
            local cs, sn = math.cos(w0), math.sin(w0)
            local alpha = sn / (2 * 0.7071)
            local a0 = 1 + alpha
            hb0 = ((1 + cs) / 2) / a0
            hb1 = -(1 + cs) / a0
            hb2 = hb0
            ha1 = (-2 * cs) / a0
            ha2 = (1 - alpha) / a0
        end)
        if not okN then
            fallbackDry(label .. " setup failed at [noise reduction init]: " .. tostring(eN), true)
            return
        end
    end

    -- one analysis/synthesis frame (prev block + current block)
    local function nrFrame()
        fc = fc + 1
        for i = 0, H - 1 do
            xr[i] = prev[i] * w[i]
            xi[i] = 0
            xr[H + i] = blk[i] * w[H + i]
            xi[H + i] = 0
        end
        fft(xr, xi)

        local S, outE = 0, 0
        for k = 0, K - 1 do
            local a, b = xr[k], xi[k]
            local P = a * a + b * b
            local ps
            if fc == 1 then ps = P else ps = Ps[k] * 0.5 + P * 0.5 end
            Ps[k] = ps
            local nn = Nn[k]
            if ps < nn then nn = ps else nn = nn * LEAK end
            Nn[k] = nn
            S = S + nn
            local g = GMIN
            if fc <= 6 then
                g = 1.0 -- warm-up: learn the noise first, pass audio untouched
            elseif ps > 0 then
                g = 1 - (nn * BIAS) / ps
                if g < GMIN then g = GMIN end
            end
            if k > CUTBIN then g = g * HFG end
            Graw[k] = g
        end

        for k = 0, K - 1 do
            local gl = Graw[(k > 0) and (k - 1) or 0]
            local gr = Graw[(k < K - 1) and (k + 1) or (K - 1)]
            local g = 0.25 * gl + 0.5 * Graw[k] + 0.25 * gr
            local pg = Gs[k]
            if g > pg then g = pg + (g - pg) * 0.6 else g = pg + (g - pg) * 0.3 end
            Gs[k] = g
            local a, b = xr[k], xi[k]
            outE = outE + (a * a + b * b) * g * g
            xr[k] = a * g
            xi[k] = b * g
            if k > 0 and k < K - 1 then
                xr[N - k] = xr[N - k] * g
                xi[N - k] = xi[N - k] * g
            end
        end

        -- inverse FFT by swapping real/imag: result real part is in xr
        fft(xi, xr)
        local invN = 1 / N
        for i = 0, H - 1 do
            outTbl[i] = olap[i] + xr[i] * invN * w[i]
            olap[i] = xr[H + i] * invN * w[H + i]
        end
        return outE > 0.5 * S
    end

    -- finished block: automatic volume, noise gate, limiter, echo, write
    local function emitBlock()
        local speech = nrFrame()
        for i = 0, H - 1 do prev[i] = blk[i] end
        bi = 0
        if skipFirst then
            skipFirst = false -- first block is only the padding in front of the audio
            return
        end

        local s2 = 0
        for i = 0, H - 1 do
            local o = outTbl[i]
            s2 = s2 + o * o
        end
        local rms = math.sqrt(s2 / H)
        if speech and rms > 15 then
            local tg = TARGET / rms
            if tg > MAXG then tg = MAXG elseif tg < 0.4 then tg = 0.4 end
            if tg < gAgc then gAgc = gAgc + (tg - gAgc) * 0.5 else gAgc = gAgc + (tg - gAgc) * 0.03 end
        end
        local gEff = gAgc
        if not speech then
            -- noise gate: nobody is speaking, push the remaining noise down
            if gEff > 1.0 then gEff = 1.0 end
            gEff = gEff * 0.35
        end

        for i = 0, H - 1 do
            gcur = gcur + (gEff - gcur) * 0.01
            local y = outTbl[i] * gcur
            local a = y
            if a < 0 then a = -a end
            if a > 26000 then
                local ex = 6767 * (1 - math.exp(-(a - 26000) / 6767))
                if y < 0 then y = -(26000 + ex) else y = 26000 + ex end
            end
            if mode == "echo" then
                local e = y + FB * ring[pos]
                if e > 32767 then e = 32767 elseif e < -32768 then e = -32768 end
                ring[pos] = e
                pos = pos + 1
                if pos >= L then pos = 0 end
                y = e
            end
            local v = math.floor(y + 0.5)
            if v > 32767 then v = 32767 elseif v < -32768 then v = -32768 end
            if v < 0 then v = v + 65536 end
            local lo = v % 256
            local hi = math.floor(v / 256)
            if lo > 127 then lo = lo - 256 end
            if hi > 127 then hi = hi - 256 end
            obuf[2 * i] = lo
            obuf[2 * i + 1] = hi
        end
        outStream.write(obuf, 0, H * 2)
        dataLen = dataLen + H * 2
    end

    local function pushSample(x)
        local y = hb0 * x + hb1 * hx1 + hb2 * hx2 - ha1 * hy1 - ha2 * hy2
        hx2 = hx1
        hx1 = x
        hy2 = hy1
        hy1 = y
        blk[bi] = y
        bi = bi + 1
        if bi >= H then emitBlock() end
    end

    local function processNR(bytes, n)
        local i = 0
        while i + 1 < n do
            local lo = bytes[i]
            if lo < 0 then lo = lo + 256 end
            pushSample(bytes[i + 1] * 256 + lo)
            i = i + 2
        end
    end

    -- plain echo, used only for non-mono recordings in echo mode
    local function processEchoRaw(bytes, n)
        local i = 0
        while i + 1 < n do
            local lo = bytes[i]
            if lo < 0 then lo = lo + 256 end
            local x = bytes[i + 1] * 256 + lo
            local y = x + FB * (ring[pos] or 0)
            if y > 32767 then y = 32767 elseif y < -32768 then y = -32768 end
            y = math.floor(y + 0.5)
            ring[pos] = y
            pos = pos + 1
            if pos >= L then pos = 0 end
            local v = y
            if v < 0 then v = v + 65536 end
            local l = v % 256
            local h = math.floor(v / 256)
            if l > 127 then l = l - 256 end
            if h > 127 then h = h - 256 end
            bytes[i] = l
            bytes[i + 1] = h
            i = i + 2
        end
        outStream.write(bytes, 0, n)
        dataLen = dataLen + n
    end

    -- non-mono recordings in call/mic mode: copied unchanged
    local function processPlain(bytes, n)
        outStream.write(bytes, 0, n)
        dataLen = dataLen + n
    end

    local function processBytes(bytes, n)
        if useNR then
            processNR(bytes, n)
        elseif mode == "echo" then
            processEchoRaw(bytes, n)
        else
            processPlain(bytes, n)
        end
    end

    -- push the last partial block and one extra block of silence so the
    -- final overlap is written out
    local function flushStream()
        if not useNR then return end
        while bi ~= 0 do pushSample(0) end
        for _ = 1, H do pushSample(0) end
    end

    -- progress dialog
    local layout = {
        LinearLayout, orientation="vertical", padding="20dp",
        {TextView, id="lblEchoProg", text="Starting...", textSize="18sp", gravity="center", layout_marginBottom="15dp"},
        {Button, id="btnEchoCancel", text="Cancel (save unprocessed)", layout_width="fill", height="50dp"}
    }
    dlg = LuaDialog(ctx).setView(loadlayout(layout))
    local handler = Handler(Looper.getMainLooper())
    local info = nil
    if not isPcm then info = MediaCodec.BufferInfo() end
    local tick

    btnEchoCancel.onClick = safe(function()
        cancelled = true
        pcall(function() handler.removeCallbacks(tick) end)
        fallbackDry(label .. " cancelled", false)
    end)

    local function complete()
        local hdrOk = pcall(function()
            pcall(function() outStream.close() end)
            outStream = nil
            local raf = RandomAccessFile(outPath, "rw")
            raf.seek(0)
            raf.write(wavHeader(dataLen, RATE, CH))
            raf.close()
        end)
        cleanupAll()
        if hdrOk then
            finishWith(outPath, label .. " recording cleaned and saved", false)
        else
            fallbackDry("Could not finish the " .. label .. " file", true)
        end
    end

    tick = Runnable({
        run = function()
            if cancelled then return end
            local okT, errT = pcall(function()
                local t0 = os.clock()
                while (os.clock() - t0) < 0.03 and not finished do
                    local progressed = false

                    if not outputDone then
                        if isPcm then
                            -- raw PCM file: read a small chunk, process, write
                            local n = inStream.read(buf, 0, READ_N)
                            if n == nil or n <= 0 then
                                outputDone = true
                                if mode == "echo" then
                                    tailLeft = 2 * RATE * CH * 2 -- 2 seconds of echo tail
                                end
                            else
                                readBytes = readBytes + n
                                n = n - (n % 2)
                                if n > 0 then processBytes(buf, n) end
                            end
                            progressed = true
                        else
                            -- compressed file: feed decoder, drain decoder
                            if not inputDone then
                                local idx = codec.dequeueInputBuffer(0)
                                if idx >= 0 then
                                    local inBuf = codec.getInputBuffer(idx)
                                    local size = extractor.readSampleData(inBuf, 0)
                                    if size < 0 then
                                        codec.queueInputBuffer(idx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                        inputDone = true
                                    else
                                        lastTime = extractor.getSampleTime()
                                        codec.queueInputBuffer(idx, 0, size, lastTime, 0)
                                        extractor.advance()
                                    end
                                    progressed = true
                                end
                            end
                            local oi = codec.dequeueOutputBuffer(info, 0)
                            if oi >= 0 then
                                local size = info.size
                                if size > 0 then
                                    local ob = codec.getOutputBuffer(oi)
                                    local bytes = newBytes(size)
                                    ob.position(info.offset)
                                    ob.get(bytes, 0, size)
                                    processBytes(bytes, size)
                                end
                                local f = info.flags
                                codec.releaseOutputBuffer(oi, false)
                                if math.floor(f / 4) % 2 == 1 then
                                    outputDone = true
                                    if mode == "echo" then
                                        tailLeft = 2 * RATE * CH * 2
                                    end
                                end
                                progressed = true
                            elseif oi ~= -1 then
                                progressed = true -- format/buffer change notices
                            end
                        end

                    elseif tailLeft > 0 then
                        local n = math.min(tailLeft, READ_N)
                        n = n - (n % 2)
                        if n <= 0 then
                            tailLeft = 0
                        else
                            local z = zbuf
                            if not useNR then z = newBytes(n) end
                            processBytes(z, n)
                            tailLeft = tailLeft - n
                        end
                        progressed = true
                    else
                        if not flushed then
                            flushStream()
                            flushed = true
                        end
                        finished = true
                    end

                    if not progressed then break end
                end
            end)

            if not okT then
                fallbackDry(label .. " error while processing: " .. tostring(errT), true)
            elseif finished then
                complete()
            else
                local pct = 99
                if not outputDone then
                    if isPcm and total > 0 then
                        pct = math.min(99, math.floor(readBytes * 100 / total))
                    elseif (not isPcm) and durationUs > 0 then
                        pct = math.min(99, math.floor(lastTime * 100 / durationUs))
                    end
                end
                local text
                if mode == "echo" then
                    text = "Cleaning noise and adding echo... " .. pct .. "%"
                else
                    text = "Cleaning noise and boosting voice... " .. pct .. "%"
                end
                pcall(function() lblEchoProg.setText(text) end)
                handler.postDelayed(tick, 5)
            end
        end
    })

    dlg.show()
    handler.post(tick)
end

function stopRecording()
    pcall(function()
        if _G.rec_is_recorder_paused and _G.rec_instance then
            pcall(function() _G.rec_instance.resume() end)
        end
    end)
    releaseRecorderResources()

    local path = _G.rec_file_path
    local mode = _G.rec_proc_mode
    if path and File(path).exists() then
        if mode then
            startProcessing(path, mode)
            return
        end
        -- raw PCM without processing: wrap it into a playable WAV file
        if string.find(string.lower(path), "%.pcm$") then
            local wav = tempFolder .. "Temp_" .. os.time() .. ".wav"
            if rawToWav(path, wav, _G.rec_pcm_rate or 16000, 1) then
                pcall(function() File(path).delete() end)
                _G.rec_file_path = wav
                _G.temp_file_path = wav
            else
                showErrorDialog("Save problem", "Could not convert the raw recording to WAV. The raw file is in the Temp folder: " .. tostring(path))
            end
        end
    end
    showResult()
end

------------------------------------------------------------
-- Playback
------------------------------------------------------------
local function releaseEnhancer()
    pcall(function()
        if _G.loudness_enhancer then
            pcall(function() _G.loudness_enhancer.setEnabled(false) end)
            pcall(function() _G.loudness_enhancer.release() end)
            _G.loudness_enhancer = nil
        end
    end)
end

function playAudio()
    if not _G.rec_file_path or not File(_G.rec_file_path).exists() then
        say("No file to play")
        return
    end

    pcall(function()
        releaseEnhancer()
        if _G.rec_player then
            pcall(function() _G.rec_player.stop() end)
            pcall(function() _G.rec_player.release() end)
            _G.rec_player = nil
        end

        _G.rec_player = MediaPlayer()
        _G.rec_player.setDataSource(_G.rec_file_path)
        _G.rec_player.prepare()

        local sessionId = _G.rec_player.getAudioSessionId()
        pcall(function()
            _G.loudness_enhancer = LoudnessEnhancer(sessionId)
            _G.loudness_enhancer.setTargetGain(2000)
            _G.loudness_enhancer.setEnabled(true)
        end)

        _G.rec_player.setOnCompletionListener(MediaPlayer.OnCompletionListener{
            onCompletion = function(mp)
                _G.is_paused = false
                releaseEnhancer()
            end
        })

        _G.rec_player.start()
        _G.is_paused = false
        say("Playing Audio")
    end)
end

function stopPlayer()
    pcall(function()
        releaseEnhancer()
        if _G.rec_player then
            pcall(function() _G.rec_player.stop() end)
            pcall(function() _G.rec_player.release() end)
            _G.rec_player = nil
        end
        _G.is_paused = false
    end)
end

------------------------------------------------------------
-- Trim (always releases extractor/muxer, deletes partial output)
------------------------------------------------------------
local function trimLastSeconds(inputPath, removeSeconds, outputPath)
    local extractor, muxer
    local muxerStarted = false

    local ok, err = pcall(function()
        extractor = MediaExtractor()
        extractor.setDataSource(inputPath)

        local trackIndex, format = -1, nil
        for i = 0, extractor.getTrackCount() - 1 do
            local f = extractor.getTrackFormat(i)
            local mime = f.getString(MediaFormat.KEY_MIME)
            if mime and string.find(mime, "audio/", 1, true) then
                trackIndex = i
                format = f
                break
            end
        end
        if trackIndex < 0 then error("No audio track found in this file") end
        if not format.containsKey(MediaFormat.KEY_DURATION) then
            error("Cannot read the recording length")
        end

        local durationUs = format.getLong(MediaFormat.KEY_DURATION)
        local targetEndUs = durationUs - (removeSeconds * 1000000)
        if targetEndUs <= 0 then error("Trim length is longer than the recording") end

        extractor.selectTrack(trackIndex)

        muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        local muxerTrack = muxer.addTrack(format)
        muxer.start()
        muxerStarted = true

        local buffer = ByteBuffer.allocate(1024 * 1024)
        local bufferInfo = MediaCodec.BufferInfo()

        while true do
            buffer.clear()
            local sampleSize = extractor.readSampleData(buffer, 0)
            if sampleSize < 0 then break end
            local pts = extractor.getSampleTime()
            if pts > targetEndUs then break end

            bufferInfo.offset = 0
            bufferInfo.size = sampleSize
            bufferInfo.presentationTimeUs = pts
            bufferInfo.flags = extractor.getSampleFlags()
            muxer.writeSampleData(muxerTrack, buffer, bufferInfo)
            extractor.advance()
        end
    end)

    -- cleanup runs on BOTH success and failure
    if muxer then
        if muxerStarted then pcall(function() muxer.stop() end) end
        pcall(function() muxer.release() end)
    end
    if extractor then pcall(function() extractor.release() end) end

    if not ok then
        pcall(function() File(outputPath).delete() end)
        error(err)
    end
    return true
end

function showTrimDialog(parentDialog)
    if not _G.rec_file_path or not File(_G.rec_file_path).exists() then
        say("No file found to trim")
        return
    end
    if string.find(string.lower(_G.rec_file_path), "%.wav$") then
        toast("Trim is not available for WAV recordings")
        say("Trim is not available for this recording type")
        return
    end

    local layout = {
        LinearLayout, orientation="vertical", padding="20dp",
        {TextView, text="Trim Audio", textSize="16sp", gravity="center", layout_marginBottom="10dp"},
        {EditText, id="editTrimSec", hint="Remove last X seconds (e.g. 5)", inputType="number", layout_width="fill", height="50dp", layout_marginBottom="20dp"},
        {Button, id="btnApplyTrim", text="Apply Trim & Save", layout_width="fill", height="45dp", layout_marginBottom="10dp"},
        {Button, id="btnCancelTrim", text="Cancel", layout_width="fill", height="45dp"}
    }

    local trimDialog = LuaDialog(ctx).setView(loadlayout(layout))

    btnApplyTrim.onClick = safe(function()
        local valObj = editTrimSec.getText()
        local seconds = tonumber(valObj and tostring(valObj) or "")
        if not seconds or seconds <= 0 then
            say("Please enter a valid number of seconds")
            return
        end

        stopPlayer() -- release file lock before reading
        local outputPath = saveFolder .. "Trimmed_" .. os.time() .. EXT
        local sourcePath = _G.rec_file_path
        local ok, err = pcall(trimLastSeconds, sourcePath, seconds, outputPath)

        if ok then
            -- tidy up: the untrimmed temp copy is no longer needed
            if isInTemp(sourcePath) then
                pcall(function() File(sourcePath).delete() end)
            end
            _G.rec_file_path = outputPath
            scanFile(outputPath)
            say("Trim applied successfully")
            trimDialog.dismiss()
            if parentDialog then
                parentDialog.dismiss()
                showResult()
            end
        else
            say("Trim failed")
            toast("Trim error: " .. tostring(err))
        end
    end)

    btnCancelTrim.onClick = safe(function() trimDialog.dismiss() end)
    trimDialog.show()
end

------------------------------------------------------------
-- Rename / Save / Delete
------------------------------------------------------------
function showRenameDialog(parentDialog)
    if not _G.rec_file_path or not File(_G.rec_file_path).exists() then
        say("No file found to rename")
        return
    end

    local layout = {
        LinearLayout, orientation="vertical", padding="20dp",
        {TextView, text="Rename Recording", textSize="16sp", gravity="center", layout_marginBottom="10dp"},
        {EditText, id="editFileName", hint="Enter new file name", layout_width="fill", height="50dp", layout_marginBottom="20dp"},
        {Button, id="btnSaveName", text="Save Name", layout_width="fill", height="45dp", layout_marginBottom="10dp"},
        {Button, id="btnCancelName", text="Cancel", layout_width="fill", height="45dp"}
    }

    local renameDialog = LuaDialog(ctx).setView(loadlayout(layout))

    btnSaveName.onClick = safe(function()
        local textVal = editFileName.getText()
        if textVal then
            local newName = tostring(textVal):gsub("%s+", "_"):gsub("[^%w_%-]", "")
            if newName ~= "" then
                -- renaming always moves the file to the permanent folder,
                -- so a renamed file can never be auto-deleted from Temp
                local ext = string.match(_G.rec_file_path, "%.%w+$") or EXT
                local newPath = saveFolder .. newName .. ext
                if File(newPath).exists() and newPath ~= _G.rec_file_path then
                    newPath = saveFolder .. newName .. "_" .. os.time() .. ext
                end

                stopPlayer() -- release file lock
                if newPath == _G.rec_file_path or moveFile(_G.rec_file_path, newPath) then
                    _G.rec_file_path = newPath
                    scanFile(newPath)
                    say("File renamed and saved")
                else
                    say("Could not rename file")
                end
                renameDialog.dismiss()
            else
                say("Please enter a valid name")
            end
        end
    end)

    btnCancelName.onClick = safe(function() renameDialog.dismiss() end)
    renameDialog.show()
end

function saveCurrentFile()
    if not _G.rec_file_path or not File(_G.rec_file_path).exists() then
        say("Nothing to save")
        return false
    end
    if not isInTemp(_G.rec_file_path) then
        say("Already saved")
        return true
    end

    stopPlayer()
    local ext = string.match(_G.rec_file_path, "%.%w+$") or EXT
    local finalPath = saveFolder .. "Saved_" .. os.time() .. ext
    if moveFile(_G.rec_file_path, finalPath) then
        _G.rec_file_path = finalPath
        scanFile(finalPath)
        say("Recording Saved Successfully")
        return true
    else
        say("Save failed")
        return false
    end
end

function confirmAndDelete(parentDialog, afterDelete)
    askConfirm("Are you sure you want to delete this recording?", "Delete", "Cancel", function()
        stopPlayer()
        pcall(function()
            if _G.rec_file_path and File(_G.rec_file_path).exists() then
                File(_G.rec_file_path).delete()
            end
        end)
        _G.rec_file_path = nil
        _G.temp_file_path = nil
        say("Recording Deleted")
        if parentDialog then parentDialog.dismiss() end
        if afterDelete then afterDelete() end
    end)
end

------------------------------------------------------------
-- Share
------------------------------------------------------------
function shareFile()
    if not _G.rec_file_path or not File(_G.rec_file_path).exists() then
        say("Save file first to share")
        return
    end

    local file = File(_G.rec_file_path)
    local uri = nil

    pcall(function()
        local pkg = ctx.getPackageName()
        local FileProvider = luajava.bindClass("androidx.core.content.FileProvider")
        uri = FileProvider.getUriForFile(ctx, pkg .. ".fileprovider", file)
    end)

    local intent = Intent(Intent.ACTION_SEND)
    intent.setType("audio/*")

    if uri then
        intent.putExtra(Intent.EXTRA_STREAM, uri)
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    else
        local ok = pcall(function()
            uri = Uri.fromFile(file)
            intent.putExtra(Intent.EXTRA_STREAM, uri)
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        end)
        if not ok then
            toast("Cannot share this file on this Android version")
            return
        end
    end

    local ok2, err = pcall(function()
        local chooser = Intent.createChooser(intent, "Share Audio via")
        chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ctx.startActivity(chooser)
    end)
    if not ok2 then toast("Could not open the share menu: " .. tostring(err)) end
end

------------------------------------------------------------
-- Result screen (also used for opening a recording from the list)
------------------------------------------------------------
function showResult(title, fromList)
    local fileSizeText = getFileSizeFormatted(_G.rec_file_path)
    local shownName = ""
    pcall(function()
        if _G.rec_file_path then shownName = tostring(File(_G.rec_file_path).getName()) end
    end)

    local layout = {
        LinearLayout, orientation="vertical", padding="20dp",
        {TextView, text=(title or "Recording Complete"), textSize="18sp", gravity="center", layout_marginBottom="5dp"},
        {TextView, text=shownName, textSize="13sp", gravity="center", layout_marginBottom="5dp"},
        {TextView, id="lblSize", text="Size: " .. fileSizeText, textSize="14sp", gravity="center", layout_marginBottom="15dp"},
        {Button, id="btnPlay", text="Play / Pause Audio", layout_width="fill", height="45dp", layout_marginBottom="8dp"},
        {Button, id="btnTrim", text="Trim Audio", layout_width="fill", height="45dp", layout_marginBottom="8dp"},
        {Button, id="btnSave", text="Save Recording", layout_width="fill", height="45dp", layout_marginBottom="8dp"},
        {Button, id="btnRename", text="Rename Recording", layout_width="fill", height="45dp", layout_marginBottom="8dp"},
        {Button, id="btnDelete", text="Delete Recording", layout_width="fill", height="45dp", layout_marginBottom="8dp"},
        {Button, id="btnShare", text="Share File", layout_width="fill", height="45dp", layout_marginBottom="8dp"},
        {Button, id="btnClose", text="Close", layout_width="fill", height="45dp"}
    }

    local d = LuaDialog(ctx).setView(loadlayout(layout))

    btnPlay.onClick = safe(function()
        if _G.rec_player and _G.rec_player.isPlaying() then
            pcall(function()
                _G.rec_player.pause()
                _G.is_paused = true
                say("Paused")
            end)
        elseif _G.is_paused and _G.rec_player then
            pcall(function()
                _G.rec_player.start()
                _G.is_paused = false
                say("Resumed")
            end)
        else
            playAudio()
        end
    end)

    btnTrim.onClick = safe(function() showTrimDialog(d) end)

    btnSave.onClick = safe(function()
        saveCurrentFile()
        lblSize.setText("Size: " .. getFileSizeFormatted(_G.rec_file_path))
    end)

    btnRename.onClick = safe(function() showRenameDialog(d) end)

    btnDelete.onClick = safe(function()
        local after = nil
        if fromList then after = showRecordingsList end
        confirmAndDelete(d, after)
    end)

    btnShare.onClick = safe(function() shareFile() end)

    -- warn before closing with an unsaved recording
    btnClose.onClick = safe(function()
        stopPlayer()
        if _G.rec_file_path and File(_G.rec_file_path).exists() and isInTemp(_G.rec_file_path) then
            local layout2 = {
                LinearLayout, orientation="vertical", padding="20dp",
                {TextView, text="This recording is not saved yet and will be deleted automatically. Save it now?", textSize="16sp", gravity="center", layout_marginBottom="20dp"},
                {Button, id="btnUnsSave", text="Save & Close", layout_width="fill", height="45dp", layout_marginBottom="10dp"},
                {Button, id="btnUnsDiscard", text="Discard & Close", layout_width="fill", height="45dp", layout_marginBottom="10dp"},
                {Button, id="btnUnsBack", text="Go Back", layout_width="fill", height="45dp"}
            }
            local ud = LuaDialog(ctx).setView(loadlayout(layout2))

            btnUnsSave.onClick = safe(function()
                if saveCurrentFile() then
                    ud.dismiss()
                    d.dismiss()
                end
            end)
            btnUnsDiscard.onClick = safe(function()
                pcall(function() File(_G.rec_file_path).delete() end)
                _G.rec_file_path = nil
                _G.temp_file_path = nil
                ud.dismiss()
                d.dismiss()
            end)
            btnUnsBack.onClick = safe(function() ud.dismiss() end)
            ud.show()
        else
            d.dismiss()
            if fromList then showRecordingsList() end
        end
    end)

    d.show()
end

------------------------------------------------------------
-- My Recordings: every saved recording, newest first. Tap one to
-- Play / Pause, Trim, Rename, Delete or Share it.
------------------------------------------------------------
function showRecordingsList()
    initFolders()
    local items = {}
    pcall(function()
        local files = File(saveFolder).listFiles()
        if files then
            for i = 0, #files - 1 do
                local f = files[i]
                local name = tostring(f.getName())
                local lower = string.lower(name)
                if f.isFile() and (string.find(lower, "%.m4a$") or string.find(lower, "%.wav$")
                    or string.find(lower, "%.aac$") or string.find(lower, "