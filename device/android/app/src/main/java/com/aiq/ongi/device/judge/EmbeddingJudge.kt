package com.aiq.ongi.device.judge

import org.json.JSONObject
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * 임베딩 판단 (판단 규칙 ③, DEV-08). 키워드로 못 정한 말만 본다.
 *  - 기준 문장(학습 데이터 전체)과 코사인(= 내적, 벡터는 정규화됨)을 잰다
 *  - 가장 가까운 "상황 문장"(번호 1~12)과 가장 가까운 "일반·불명확 문장"(번호 0)을 따로 찾는다
 *  - 상황 문장이 margin 넘게 더 가깝고, 그 점수가 threshold 이상이면 → 그 상황
 *  - 아니면 → 없음
 * 11/2: 점수 하나만 보면 짧은 문장끼리 점수가 다 높아서 일반 대화를 많이 잡음(학습 LOO 308 중 129)
 *       → 일반 문장과의 차이(margin)를 같이 봄(308 중 22).
 * 기준 문장·값은 Colab 노트북이 만든 anchors.f32 / anchors_meta.json.
 */
class EmbeddingJudge(
    private val vectors: Array<FloatArray>,
    private val ids: IntArray,
    private val texts: List<String>,
    val threshold: Float,
    val margin: Float,
) {
    data class Result(
        val situation: Int?,       // 정한 상황 (없으면 null)
        val score: Float,          // 가장 가까운 상황 문장 점수
        val nearestId: Int,        // 그 문장 번호
        val nearestText: String,
        val generalScore: Float,   // 가장 가까운 일반·불명확 문장 점수
    )

    val size get() = ids.size

    fun judge(vec: FloatArray): Result {
        var bestS = -1; var bestSScore = -2f
        var bestGScore = -2f
        for (i in vectors.indices) {
            val s = dot(vectors[i], vec)
            if (ids[i] == 0) { if (s > bestGScore) bestGScore = s }
            else if (s > bestSScore) { bestSScore = s; bestS = i }
        }
        if (bestS < 0) return Result(null, 0f, 0, "", bestGScore)
        val ok = bestSScore - bestGScore > margin && bestSScore >= threshold
        return Result(if (ok) ids[bestS] else null, bestSScore, ids[bestS], texts[bestS], bestGScore)
    }

    private fun dot(a: FloatArray, b: FloatArray): Float {
        var s = 0f
        for (i in a.indices) s += a[i] * b[i]
        return s
    }

    companion object {
        fun load(dir: File): EmbeddingJudge {
            val meta = JSONObject(File(dir, "anchors_meta.json").readText())
            val dim = meta.getInt("dim")
            val count = meta.getInt("count")
            val idsJson = meta.getJSONArray("ids")
            val textsJson = meta.getJSONArray("texts")
            val buf = ByteBuffer.wrap(File(dir, "anchors.f32").readBytes()).order(ByteOrder.LITTLE_ENDIAN).asFloatBuffer()
            require(buf.remaining() == dim * count) { "anchors.f32 크기가 맞지 않음: ${buf.remaining()} ≠ $dim × $count" }
            val vectors = Array(count) { FloatArray(dim).also { v -> buf.get(v) } }
            return EmbeddingJudge(
                vectors = vectors,
                ids = IntArray(count) { idsJson.getInt(it) },
                texts = List(count) { textsJson.getString(it) },
                threshold = meta.getDouble("threshold").toFloat(),
                margin = meta.optDouble("margin", 0.0).toFloat(),
            )
        }
    }
}
