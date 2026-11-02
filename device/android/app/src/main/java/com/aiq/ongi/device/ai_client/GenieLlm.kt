package com.aiq.ongi.device.ai_client

import com.aiq.ongi.device.Config
import com.suda.agent.engine.LlmClient
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.TimeUnit

/**
 * 보드 NPU에서 LLM 실행 (Qualcomm Genie, SUDA 앱과 같은 방식). DEV-08 LLM 부분.
 *
 *  - 설정: Genie json 경로(Config.LLM_CONFIG). 학습 모델이 오면 json(·context binary·tokenizer)만 바꾼다
 *  - 프롬프트: Config.LLM_PROMPT_PREFIX + 마음AI 템플릿 + 아이 말 + " Response:"
 *    SUDA 앱은 앞에 "<|im_start|>"를 붙인다. 우리 모델 학습 방식에 맞춰 Config에서 바꾼다(멘토 확인)
 *  - 모델 읽기는 무거워서(1.6GB) 뒤에서 한 번만. 다 읽기 전·실패 시 ready=false → 부르는 쪽이 가짜로 대신
 *  - Genie는 동시에 한 문장만: 전용 스레드 하나로 순서대로
 */
class GenieLlm(private val log: (String) -> Unit) : AutoCloseable {
    private val worker = Executors.newSingleThreadExecutor()
    private var client: LlmClient? = null
    @Volatile var ready = false
        private set
    @Volatile var lastMs = 0L
        private set

    /** 뒤에서 모델 읽기 시작 */
    fun startLoading(configPath: String = Config.LLM_CONFIG) {
        worker.execute {
            try {
                if (!File(configPath).canRead()) {
                    log("LLM: 설정 파일을 읽을 수 없음 → 가짜 LLM 사용 ($configPath)")
                    return@execute
                }
                val t0 = System.currentTimeMillis()
                val c = LlmClient()
                val rc = c.Init(configPath)
                if (rc == 0) {
                    client = c
                    ready = true
                    log("LLM: Genie 준비 완료 (${System.currentTimeMillis() - t0}ms, $configPath)")
                } else {
                    log("LLM: Genie Init 실패 rc=$rc → 가짜 LLM 사용")
                }
            } catch (e: Throwable) {
                log("LLM: Genie 읽기 실패 → 가짜 LLM 사용: ${e.javaClass.simpleName} ${e.message}")
            }
        }
    }

    /** 아이 말 → LLM 출력 원문. 준비 안 됐거나 시간 초과면 예외(부르는 쪽이 처리) */
    fun infer(text: String): String {
        val c = client
        check(ready && c != null) { "Genie 준비 안 됨" }
        // context 128 토큰: 고정 29 + 출력 최대 30 → 아이 말 69토큰(약 98자)까지 안전. 넉넉히 60자로 자른다 (11/2 count_tokens.py)
        val query = text.trim().removeSuffix(".").removeSuffix("?").take(MAX_QUERY_CHARS)
        val prompt = Config.LLM_PROMPT_PREFIX + TEMPLATE_HEAD + query + TEMPLATE_TAIL
        val f: Future<String> = worker.submit<String> {
            val t0 = System.currentTimeMillis()
            val out = c.Infer(prompt)
            lastMs = System.currentTimeMillis() - t0
            out
        }
        return f.get(Config.LLM_TIMEOUT_MS, TimeUnit.MILLISECONDS)
    }

    override fun close() {
        worker.execute { try { client?.UnInit() } catch (_: Throwable) {} }
        worker.shutdown()
    }

    companion object {
        const val TEMPLATE_HEAD = "Below is the query from the users, please choose the correct function and generate the parameters to call the function. Query: "
        const val TEMPLATE_TAIL = " Response:"
        const val MAX_QUERY_CHARS = 60
    }
}
