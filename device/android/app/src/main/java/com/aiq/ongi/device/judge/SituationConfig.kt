package com.aiq.ongi.device.judge

import com.aiq.ongi.device.safety.SafetyChecker
import org.json.JSONArray
import org.json.JSONObject

/**
 * assets/situations.json 읽기.
 * 석준님 최종본이 오면 그 파일로 바꿔 넣기만 하면 된다(형식은 임시본과 같게).
 *
 * {
 *   "priority": [12, 2, 3, ...],
 *   "crisis": ["죽고 싶", ...],
 *   "situations": [ { "id": 4, "name": "...", "keywords": [...], "exclude": [...] }, ... ]
 * }
 */
data class SituationConfig(
    val version: String,
    val priority: List<Int>,
    val crisis: List<String>,
    val rules: List<SituationRule>,
) {
    fun keywordJudge() = KeywordJudge(rules, priority)
    fun safetyChecker() = SafetyChecker(SafetyChecker.compile(crisis))

    companion object {
        fun parse(json: String): SituationConfig {
            val o = JSONObject(json)
            val rules = o.getJSONArray("situations").let { arr ->
                (0 until arr.length()).map { i ->
                    val s = arr.getJSONObject(i)
                    SituationRule(
                        id = s.getInt("id"),
                        name = s.optString("name", "상황 ${s.getInt("id")}"),
                        keywords = strings(s.optJSONArray("keywords")),
                        exclude = strings(s.optJSONArray("exclude")),
                    )
                }
            }
            val priority = o.optJSONArray("priority")?.let { a -> (0 until a.length()).map { a.getInt(it) } }
                ?: KeywordJudge.PRIORITY
            return SituationConfig(
                version = o.optString("version", ""),
                priority = priority,
                crisis = strings(o.optJSONArray("crisis")),
                rules = rules,
            )
        }

        private fun strings(a: JSONArray?): List<String> =
            if (a == null) emptyList() else (0 until a.length()).map { a.getString(it) }
    }
}
