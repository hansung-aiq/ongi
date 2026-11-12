package com.aiq.ongi.device.ai_client

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import org.json.JSONObject
import java.io.File
import java.nio.LongBuffer

/**
 * 문장 → 384차원 벡터 (MiniLM int8, 보드 CPU). DEV-08.
 * 파일은 Colab 노트북(ai/notebooks/온기_DEV08_임베딩기준_Colab.ipynb)이 만든 것:
 *   minilm_int8.onnx    토큰 → 벡터 (평균·정규화까지 모델 안에서 함)
 *   vocab.tsv           토크나이저 단어장 (UnigramTokenizer가 읽음)
 *   anchors_meta.json   unk·시작·끝 토큰 번호 등
 */
class OnnxEmbedder(dir: File) : AutoCloseable {
    private val env = OrtEnvironment.getEnvironment()
    private val meta = JSONObject(File(dir, "anchors_meta.json").readText())
    private val session: OrtSession
    val tokenizer = UnigramTokenizer(
        vocabFile = File(dir, meta.optString("vocab", "vocab.tsv")),
        unk = meta.optInt("unk", 3),
        unkScore = meta.optDouble("unk_score", -30.0),
        maxPiece = meta.optInt("max_piece", 32),
        bos = meta.optLong("bos", 0),
        eos = meta.optLong("eos", 2),
    )
    val dim = meta.optInt("dim", 384)

    init {
        val opts = OrtSession.SessionOptions().apply { setIntraOpNumThreads(2) }
        session = env.createSession(File(dir, meta.optString("onnx", "minilm_int8.onnx")).absolutePath, opts)
    }

    /** 글 → 정규화된 벡터 (코사인 = 내적) */
    fun embed(text: String): FloatArray {
        val ids = tokenizer.encode(text)
        val shape = longArrayOf(1, ids.size.toLong())
        OnnxTensor.createTensor(env, LongBuffer.wrap(ids), shape).use { idT ->
            OnnxTensor.createTensor(env, LongBuffer.wrap(LongArray(ids.size) { 1L }), shape).use { maskT ->
                session.run(mapOf("input_ids" to idT, "attention_mask" to maskT)).use { res ->
                    @Suppress("UNCHECKED_CAST")
                    return (res[0].value as Array<FloatArray>)[0]
                }
            }
        }
    }

    override fun close() = session.close()
}
