package com.aiq.ongi.device.respond

import com.aiq.ongi.device.Config
import com.aiq.ongi.device.EmpathyMode
import com.aiq.ongi.device.store.MessageStore
import com.aiq.ongi.device.store.ParentMessage

/** 무엇을 들려줄지 */
sealed class Decision {
    abstract val log: String

    /** 공감 한마디 → 부모 메시지 */
    data class Play(val empathy: String, val message: ParentMessage, override val log: String) : Decision()

    /** 공감 한마디만 */
    data class EmpathyOnly(val empathy: String, override val log: String) : Decision()

    /** 받아주는 말 */
    data class NotFound(val text: String, override val log: String) : Decision()
}

/**
 * 재생 규칙 (판단 규칙 ⑤⑥, 공통지침 4-8·4-9)
 *
 *  LLM 상황 = 판단 상황            → 생성 공감 + 부모 메시지
 *  둘이 다름(판단 상황 없음 포함)  → 생성 공감만
 *  LLM 상황 -1                     → 생성 공감만
 *  일반 대화(<maum_1>)             → 받아주는 말
 *  LLM 없음·실패                   → 판단 결과대로 미리 쓴 공감 + 부모 메시지
 *  그 상황에 부모 메시지 없음      → 생성 공감만(생성 실패 시 받아주는 말)
 */
class Responder(private val store: MessageStore) {

    /**
     * @param judged 키워드·임베딩으로 판단한 상황 (없으면 null)
     * @param infer  LLM 결과 (없거나 형식이 깨졌으면 null)
     */
    fun decide(judged: Int?, infer: InferResult?): Decision {
        // LLM 없음·실패 → 판단 결과대로
        if (infer == null) {
            if (judged == null) return Decision.NotFound(FallbackLines.acknowledge(), "LLM 실패, 판단 없음 → 받아주는 말")
            val msg = store.find(judged)
            val line = FallbackLines.open()
            return if (msg != null) Decision.Play(line, msg, "LLM 실패 → 판단 상황 $judged 대로, 대체 공감 + 메시지")
            else Decision.EmpathyOnly(line, "LLM 실패, 상황 $judged 메시지 없음 → 대체 공감만")
        }

        // 일반 대화
        if (infer.general) return Decision.NotFound(FallbackLines.acknowledge(), "일반 대화 → 받아주는 말")

        // 판단 상황과 LLM 상황이 같고 메시지가 있을 때만 부모 메시지
        val agree = judged != null && infer.situation == judged
        val msg = if (agree) store.find(judged!!) else null

        if (agree && msg == null) {
            // 그 상황에 부모 메시지 없음 → 생성 공감만, 생성 실패 시 받아주는 말
            val gen = generated(infer)
            return if (gen.text != null) Decision.EmpathyOnly(gen.text, "상황 $judged 메시지 없음 → ${gen.log}")
            else Decision.NotFound(FallbackLines.acknowledge(), "상황 $judged 메시지 없음, ${gen.log} → 받아주는 말")
        }

        val empathy = empathyText(infer, playing = msg != null)
        return if (msg != null) {
            Decision.Play(empathy.first, msg, "판단 $judged = LLM ${infer.situation} → 공감 + 메시지 (${empathy.second})")
        } else {
            val why = if (infer.situation == -1) "LLM 상황 -1" else "판단 $judged ≠ LLM ${infer.situation}"
            Decision.EmpathyOnly(empathy.first, "$why → 공감만 (${empathy.second})")
        }
    }

    private class Gen(val text: String?, val log: String)

    /** 생성 공감 검사. 통과하면 그 문장, 아니면 null + 이유 */
    private fun generated(infer: InferResult): Gen {
        if (Config.empathyMode == EmpathyMode.SELECT) return Gen(null, "select 모드")
        val reasons = EmpathyChecker.check(infer.empathy, infer.feeling)
        return if (reasons.isEmpty()) Gen(infer.empathy, "생성")
        else Gen(null, "대체(${reasons.joinToString(", ")})")
    }

    /** 생성 공감을 쓰고, 어기면 미리 쓴 공감으로 대체. (문장, 로그) */
    private fun empathyText(infer: InferResult, playing: Boolean): Pair<String, String> {
        val gen = generated(infer)
        if (gen.text != null) return gen.text to gen.log
        // 대체: 부모 메시지를 재생하고 기분이 있으면 짚는 말, 그 밖은 열어 두는 말
        // TODO 상황별 허용 기분·기본 기분은 situations.json(석준) 받은 뒤 반영
        val line = if (playing && infer.feeling != -1) FallbackLines.pointed(infer.feeling) else FallbackLines.open()
        return line to gen.log
    }
}
