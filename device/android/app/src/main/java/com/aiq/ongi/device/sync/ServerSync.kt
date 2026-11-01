package com.aiq.ongi.device.sync

import com.aiq.ongi.device.store.MessageStore

/**
 * 서버(정범) ↔ 보드 동기화. DEV-09(11/8~11)에서 채운다.
 *
 * 할 일
 *  - 30초마다 API-11(since)로 새 메시지 확인
 *  - 새 녹음은 API-12로 받아 16kHz wav로 변환, 글 메시지는 /tts로 미리 wav
 *  - 받은 뒤 API-13으로 "전달됨" 알림
 *  - deleted=true면 보드 안 메시지·wav 삭제
 *  - 재생하면 play_logs 저장 + API-14(message_id, played_at)
 */
class ServerSync(
    private val store: MessageStore,
    private val log: (String) -> Unit,
) {
    fun syncOnce() {
        log("동기화: 아직 구현 전 (DEV-09). 메시지 ${store.all().size}개(시연용 고정)")
    }

    fun reportPlayed(messageId: Int) {
        log("재생 기록: message_id=$messageId (API-14는 DEV-09에서)")
    }
}
