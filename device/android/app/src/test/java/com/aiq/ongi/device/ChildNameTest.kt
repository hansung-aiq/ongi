package com.aiq.ongi.device

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Test

class ChildNameTest {
    private val original = Config.CHILD_NAME

    @After
    fun restore() {
        Config.CHILD_NAME = original
    }

    @Test
    fun addsIOnlyWithBatchim() {
        Config.CHILD_NAME = "민준"
        assertEquals("민준이", Config.childNameI())
        Config.CHILD_NAME = "서아"
        assertEquals("서아", Config.childNameI())
        Config.CHILD_NAME = "Alex"
        assertEquals("Alex", Config.childNameI())
    }
}
