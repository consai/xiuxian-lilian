import assert from "node:assert/strict";
import { validateEffectRows } from "./validate-effect-rows.mjs";

const schema = {
  damage: { 参数1: "固定值", 参数2: "自身属性", 参数3: "自身比例", 参数4: "目标属性", 参数5: "目标比例" },
  hp: { 参数1: "固定恢复值", 参数2: null, 参数3: null, 参数4: null, 参数5: null },
};

assert.deepEqual(validateEffectRows([["damage", 10]], schema, "skill"), []);
assert.deepEqual(validateEffectRows([["damage", 10, "magic_atk", 100, "hp_max", 0]], schema, "skill"), []);
assert.match(validateEffectRows([["missing", 1]], schema, "skill")[0], /未登记效果/);
assert.match(validateEffectRows([["hp", 1, 2]], schema, "item")[0], /参数数量应为 1-1/);
assert.match(validateEffectRows([["hp", null]], schema, "item")[0], /缺少参数 固定恢复值/);

console.log("PASS: validate-effect-rows raw export schema");
