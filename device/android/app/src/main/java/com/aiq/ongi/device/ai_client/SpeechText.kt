package com.aiq.ongi.device.ai_client

/**
 * TTS에 넣기 전 글 정리 (11/10, 시연 중단 리스크 S4).
 * 한국어 VITS 모델은 이모지·기호·낱자(ㅋㅋ)를 읽지 못하거나 이상하게 읽을 수 있어서 빼고 넣는다.
 * 화면에 보이는 글(신호의 text)은 그대로 두고, 소리만 이 글로 만든다.
 *
 * 남기는 것: 한글 음절, 영문, 숫자, 띄어쓰기, 문장부호(. , ! ? ~ ' " ·)
 * 빼는 것  : 이모지, 하트·별 같은 기호, 한글 낱자(ㅋ, ㅠ), 그 밖의 특수문자
 * 숫자·영어는 그대로 둔다(읽는 법이 경우마다 달라서) → 시연 글은 한글로 쓰도록 요청
 */
object SpeechText {
    private val keep = Regex("[가-힣A-Za-z0-9 .,!?~'\"·\n]")

    fun clean(text: String): String {
        val sb = StringBuilder()
        var i = 0
        while (i < text.length) {
            val cp = text.codePointAt(i)
            val ch = String(Character.toChars(cp))
            sb.append(if (keep.matches(ch)) ch else " ")
            i += Character.charCount(cp)
        }
        val out = sb.toString()
            .replace(Regex("[ \t]+"), " ")
            .replace(Regex(" +([.,!?~])"), "$1")
            .replace(Regex("~+"), "")
            .trim()
        // 다 지워졌으면(기호만 있는 글) 원래 글을 넘겨서 적어도 무음은 피한다
        return out.ifBlank { text }
    }
}
