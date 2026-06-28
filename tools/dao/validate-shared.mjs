/** Node 配置校验共用：quality/tier 与 learningKnowledgeGatePolicy。 */

export const QUALITY_MIN = 1;
export const QUALITY_MAX = 4;
export const TIER_MIN = 1;
export const TIER_MAX = 9;

/** 从 learningKnowledgeGatePolicy 读取普通品质档位（默认 1、2）。 */
export function ordinaryQualitiesFromPolicy(policy) {
  return new Set(policy?.ordinaryQualities ?? [QUALITY_MIN, 2]);
}

/** 校验单行 quality/tier，并拒绝旧字段 rarity。 */
export function validateQualityTier(row, label, errors) {
  const rowId = row.id ?? "";
  if ("rarity" in row) {
    errors.push(`${label} ${rowId} 使用了旧字段 rarity`);
  }
  if (row.quality == null) {
    errors.push(`${label} ${rowId} 缺少 quality`);
  } else if (!Number.isInteger(row.quality) || row.quality < QUALITY_MIN || row.quality > QUALITY_MAX) {
    errors.push(`${label} ${rowId} quality 必须在 ${QUALITY_MIN}..${QUALITY_MAX}`);
  }
  if (row.tier == null) {
    errors.push(`${label} ${rowId} 缺少 tier`);
  } else if (!Number.isInteger(row.tier) || row.tier < TIER_MIN || row.tier > TIER_MAX) {
    errors.push(`${label} ${rowId} tier 必须在 ${TIER_MIN}..${TIER_MAX}`);
  }
}
