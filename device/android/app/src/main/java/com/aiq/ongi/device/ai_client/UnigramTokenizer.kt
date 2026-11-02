package com.aiq.ongi.device.ai_client

import java.io.File
import java.text.Normalizer

/**
 * MiniLM(XLM-R 계열) 토크나이저를 앱 안에서 직접 계산 (SentencePiece Unigram). DEV-08.
 * onnxruntime-extensions가 새 transformers 토크나이저를 변환하지 못해서 직접 구현했다(11/2).
 * Colab 노트북 8번 셀의 파이썬 계산과 같고, 거기서 원래 토크나이저와 학습·평가 문장 전부가 같은지 확인한다.
 *
 *  1. NFKC 정규화, 공백 하나로
 *  2. 띄어쓰기로 나누고 각 단어 앞에 "▁"
 *  3. 단어마다 점수 합이 가장 큰 조각 나누기(Viterbi). 단어장에 없는 글자는 unk(연속이면 하나로)
 *  4. 앞뒤에 <s>, </s>
 */
class UnigramTokenizer(
    vocabFile: File,
    private val unk: Int,
    private val unkScore: Double,
    private val maxPiece: Int,
    private val bos: Long,
    private val eos: Long,
) {
    private val ids = HashMap<String, Int>(300_000)
    private val scores: DoubleArray

    init {
        val sc = ArrayList<Double>(260_000)
        vocabFile.bufferedReader().useLines { lines ->
            lines.forEachIndexed { i, line ->
                val tab = line.lastIndexOf('\t')
                val piece = line.substring(0, tab)
                sc.add(line.substring(tab + 1).toDouble())
                ids.putIfAbsent(piece, i)
            }
        }
        scores = sc.toDoubleArray()
    }

    fun encode(text: String): LongArray {
        val norm = Normalizer.normalize(text, Normalizer.Form.NFKC).trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
        val out = ArrayList<Long>()
        out.add(bos)
        for (w in norm) viterbi("▁$w").forEach { out.add(it.toLong()) }
        out.add(eos)
        return out.toLongArray()
    }

    private fun viterbi(w: String): List<Int> {
        val n = w.length
        val neg = -1e30
        val best = DoubleArray(n + 1) { neg }.also { it[0] = 0.0 }
        val fromPos = IntArray(n + 1) { -1 }
        val fromId = IntArray(n + 1) { -1 }
        for (i in 0 until n) {
            if (best[i] <= neg) continue
            var single = false
            for (len in 1..minOf(maxPiece, n - i)) {
                val id = ids[w.substring(i, i + len)] ?: continue
                if (len == 1) single = true
                val v = best[i] + scores[id]
                if (v > best[i + len]) { best[i + len] = v; fromPos[i + len] = i; fromId[i + len] = id }
            }
            if (!single) {
                val v = best[i] + unkScore
                if (v > best[i + 1]) { best[i + 1] = v; fromPos[i + 1] = i; fromId[i + 1] = unk }
            }
        }
        val rev = ArrayList<Int>()
        var j = n
        while (j > 0) { rev.add(fromId[j]); j = fromPos[j] }
        rev.reverse()
        val fused = ArrayList<Int>(rev.size)
        for (x in rev) if (!(x == unk && fused.isNotEmpty() && fused.last() == unk)) fused.add(x)
        return fused
    }
}
