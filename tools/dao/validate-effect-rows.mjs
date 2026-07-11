export function validateEffectRows(rows, schema, label) {
  const errors = [];
  if (!Array.isArray(rows)) return [`${label}: effects 必须是数组`];
  for (const [index, row] of rows.entries()) {
    if (!Array.isArray(row) || !row.length) {
      errors.push(`${label}.effects[${index}]: 必须是非空数组`);
      continue;
    }
    const effectId = String(row[0] ?? "").trim().toLowerCase();
    const definition = schema.effects?.[effectId];
    if (!definition) {
      errors.push(`${label}.effects[${index}]: 未登记效果 ${effectId}`);
      continue;
    }
    const values = row.slice(1);
    if (values.length < definition.required || values.length > definition.parameters.length) {
      errors.push(`${label}.effects[${index}]: ${effectId} 参数数量应为 ${definition.required}-${definition.parameters.length}，当前 ${values.length}`);
      continue;
    }
    for (let i = 0; i < definition.required; i += 1) {
      if (values[i] == null || String(values[i]).trim() === "") errors.push(`${label}.effects[${index}]: ${effectId} 缺少参数 ${definition.parameters[i]}`);
    }
  }
  return errors;
}
