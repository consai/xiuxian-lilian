export function validateEffectRows(rows, schema, label) {
  const errors = [];
  if (!Array.isArray(rows)) return [`${label}: effects 必须是数组`];
  for (const [index, row] of rows.entries()) {
    if (!Array.isArray(row) || !row.length) {
      errors.push(`${label}.effects[${index}]: 必须是非空数组`);
      continue;
    }
    const effectId = String(row[0] ?? "").trim().toLowerCase();
    const definition = effectDefinition(schema, effectId);
    if (definition == null) {
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

function effectDefinition(schema, effectId) {
  const raw = (schema.effects ?? schema)?.[effectId];
  if (!raw) return null;
  if (Array.isArray(raw.parameters)) return raw;

  const parameters = [];
  for (let i = 1; i <= 5; i += 1) {
    const value = raw[`参数${i}`];
    if (value != null && String(value).trim() !== "") parameters.push(String(value));
  }
  return { parameters, required: parameters.length > 0 ? 1 : 0 };
}
