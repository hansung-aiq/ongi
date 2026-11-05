package com.aiq.ongi.device.audio

import java.io.File

/**
 * 오디오 A안 (11/5): root 도우미(device/tools/ongi_audio.sh)에게 재생·녹음을 맡긴다.
 * 앱(Android)에서는 USB 사운드카드로 소리가 안 나서(퀄컴 USB 오프로드), 도우미가 tinyplay/tinycap을 대신 부른다.
 *
 * 주고받기: Config.AUDIO_HELPER_DIR(/data/local/tmp/ongi/audio)
 *   앱 → 도우미 : play.req(틀 wav 경로) / rec.req(녹음 초) / stop.req
 *   도우미 → 앱 : play.done / rec.done ("ok" 또는 "error 이유"), rec.wav, alive(1초마다 시각)
 * 도우미가 꺼져 있으면 alive가 오래돼서 쓰지 않는다 → 흐름은 소리 길이만큼 기다리기만 한다.
 */
class TinyAlsaHelper(private val dir: File, private val log: (String) -> Unit = {}) {

    /** 도우미가 3초 안에 살아 있었는지 */
    val alive: Boolean
        get() = try {
            val t = File(dir, "alive").readText().trim().toLong()
            kotlin.math.abs(System.currentTimeMillis() / 1000 - t) <= 3
        } catch (_: Exception) { false }

    /** 재생 시작 (기다리지 않음). 요청을 못 쓰면 false */
    fun startPlay(wav: File): Boolean {
        if (!wav.exists()) { log("재생 파일 없음: ${wav.absolutePath}"); return false }
        File(dir, "play.done").delete()
        return request("play.req", wav.absolutePath)
    }

    /** 재생이 끝날 때까지 기다림. null이면 성공, 아니면 오류 내용 */
    fun waitPlay(timeoutMs: Long): String? = waitDone("play.done", timeoutMs)

    /** 녹음 (끝날 때까지 기다림). 48kHz 모노 16비트 wav 바이트, 실패하면 null */
    fun record(seconds: Int): ByteArray? {
        File(dir, "rec.done").delete()
        if (!request("rec.req", seconds.toString())) return null
        val err = waitDone("rec.done", seconds * 1000L + 4000)
        if (err != null) { log("녹음 실패: $err"); return null }
        return try { File(dir, "rec.wav").readBytes() } catch (e: Exception) { log("녹음 파일 읽기 실패: ${e.message}"); null }
    }

    /** 도우미가 녹음하는 파일 (녹음 중에도 늘어남, 48kHz 모노 16비트) */
    val recFile get() = File(dir, "rec.wav")

    /** 녹음 시작 (기다리지 않음). 멈추려면 stop() */
    fun startRecord(maxSeconds: Int): Boolean {
        File(dir, "rec.done").delete()
        return request("rec.req", maxSeconds.toString())
    }

    /** 녹음 끝 기다림. null이면 성공 */
    fun waitRecord(timeoutMs: Long): String? = waitDone("rec.done", timeoutMs)

    fun stop() { request("stop.req", "") }

    /** 반쯤 쓴 파일을 도우미가 읽지 않게: 임시 파일에 쓰고 이름을 바꾼다 */
    private fun request(name: String, body: String): Boolean = try {
        val tmp = File(dir, "$name.tmp")
        tmp.writeText(body)
        tmp.renameTo(File(dir, name)).also { if (!it) log("요청 실패: $name") }
    } catch (e: Exception) {
        log("요청 실패($name): ${e.message}"); false
    }

    private fun waitDone(name: String, timeoutMs: Long): String? {
        val f = File(dir, name)
        val end = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < end) {
            if (f.exists()) {
                val r = try { f.readText().trim() } catch (_: Exception) { "" }
                if (r.isNotEmpty()) { f.delete(); return if (r == "ok") null else r }
            }
            Thread.sleep(50)     // stop()이면 흐름 스레드가 끊겨 InterruptedException → 흐름이 멈춤 처리
        }
        return "시간 초과(${timeoutMs}ms)"
    }
}
