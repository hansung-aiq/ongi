package com.aiq.ongi.device

import com.aiq.ongi.device.ai_client.SpeechText
import org.junit.Assert.assertEquals
import org.junit.Test

class SpeechTextTest {
    @Test
    fun keepsPlainKorean() {
        assertEquals("민준아, 엄마는 언제나 네 편이야.", SpeechText.clean("민준아, 엄마는 언제나 네 편이야."))
    }

    @Test
    fun removesEmojiAndSymbols() {
        assertEquals("사랑해 우리 아들!", SpeechText.clean("사랑해 ❤️ 우리 아들!! 😊".replace("!!", "!")))
        assertEquals("축하해! 최고야", SpeechText.clean("축하해!🎉 ★최고야★"))
    }

    @Test
    fun removesJamoAndTilde() {
        assertEquals("잘했어", SpeechText.clean("잘했어~~ ㅋㅋㅋ"))
    }

    @Test
    fun keepsDigitsAndLatin() {
        assertEquals("3학년 때 OK", SpeechText.clean("3학년 때 OK"))
    }

    @Test
    fun symbolsOnlyFallsBackToOriginal() {
        assertEquals("❤️", SpeechText.clean("❤️"))
    }
}
