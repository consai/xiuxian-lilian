/** Node 配置校验共用：quality/tier。 */

export const QUALITY_MIN = 1;
export const QUALITY_MAX = 4;
export const TIER_MIN = 1;
export const TIER_MAX = 9;

/** 阶位与大境界 id 一一对应（与 EnumItemTier / dao_tree.realms.order 一致）。 */
export const REALM_IDS_BY_TIER = [
  "qi",
  "foundation",
  "core",
  "nascent",
  "transform",
  "void",
  "merge",
  "great",
  "tribulation",
];

/** 阶位 → 大境界 id。 */
export function realmIdForTier(tier) {
  const t = Math.max(TIER_MIN, Math.min(TIER_MAX, Number(tier) || TIER_MIN));
  return REALM_IDS_BY_TIER[t - 1] ?? "qi";
}

/** 大境界 id → 阶位。 */
export function tierForRealmId(realmId) {
  const idx = REALM_IDS_BY_TIER.indexOf(String(realmId ?? "").trim().toLowerCase());
  return idx >= 0 ? idx + 1 : TIER_MIN;
}

/** 技能/功法配置禁止再写 realm，统一用 tier。 */
export function rejectLegacyRealmField(row, label, errors) {
  const rowId = row.id ?? "";
  if ("realm" in row) {
    errors.push(`${label} ${rowId} 不得配置 realm，请仅用 tier`);
  }
  if (row.learningRequirements?.realm != null) {
    errors.push(`${label} ${rowId} learningRequirements 不得配置 realm，请仅用 tier`);
  }
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
