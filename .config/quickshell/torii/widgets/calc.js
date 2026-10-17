.pragma library

// The launcher's calculator: "2+2", "sqrt(16) * 3", "2^10", "sin(pi/2)", "15% of 200" is not supported, % is modulo.
// A small recursive-descent parser (no eval): numbers, + - * / % ^ **, unary minus, parentheses, a few functions and constants.
// evaluate(text) -> { ok: true, value, text } for an expression that is really maths (an operator, a function or a bracket),
// or { ok: false } for anything else, so a plain number or a word is left to the normal search.

const FUNCS = {
    sqrt: Math.sqrt, cbrt: Math.cbrt, sin: Math.sin, cos: Math.cos, tan: Math.tan, asin: Math.asin, acos: Math.acos,
    atan: Math.atan, ln: Math.log, log: Math.log10, log2: Math.log2, exp: Math.exp, abs: Math.abs, floor: Math.floor,
    ceil: Math.ceil, round: Math.round, pow: Math.pow, min: Math.min, max: Math.max, deg: x => x * 180 / Math.PI, rad: x => x * Math.PI / 180
};
const CONSTS = { pi: Math.PI, e: Math.E, tau: 2 * Math.PI };

function tokenize(src) {
    const out = [];
    let i = 0;
    while (i < src.length) {
        const c = src[i];
        if (c === " " || c === "\t") { i++; continue; }
        let m = /^(\d+\.?\d*|\.\d+)(e[+-]?\d+)?/i.exec(src.slice(i));
        if (m) { out.push({ t: "num", v: parseFloat(m[0]) }); i += m[0].length; continue; }
        m = /^[a-z][a-z0-9]*/i.exec(src.slice(i));
        if (m) { out.push({ t: "id", v: m[0].toLowerCase() }); i += m[0].length; continue; }
        if (src.startsWith("**", i)) { out.push({ t: "op", v: "^" }); i += 2; continue; }
        if ("+-*/%^(),×÷".indexOf(c) >= 0) { out.push({ t: "op", v: c === "×" ? "*" : c === "÷" ? "/" : c }); i++; continue; }
        return null;
    }
    return out;
}

function evaluate(src) {
    src = String(src).trim();
    if (!/[a-z]\s*\(/i.test(src)) src = src.replace(/(\d),(\d)/g, "$1.$2");      // 1,5 is 1.5 unless commas separate arguments
    if (src === "" || !/\d|pi|tau/i.test(src)) return { ok: false };
    const toks = tokenize(src);
    if (!toks || toks.length === 0) return { ok: false };
    let p = 0, mathy = false;
    const peek = () => toks[p];
    const eat = v => { if (peek() && peek().t === "op" && peek().v === v) { p++; return true; } return false; };
    const fail = () => { throw new Error("parse"); };

    function expr() {
        let v = term();
        for (;;) {
            if (eat("+")) { mathy = true; v += term(); }
            else if (eat("-")) { mathy = true; v -= term(); }
            else return v;
        }
    }
    function term() {
        let v = unary();
        for (;;) {
            if (eat("*")) { mathy = true; v *= unary(); }
            else if (eat("/")) { mathy = true; v /= unary(); }
            else if (eat("%")) { mathy = true; v %= unary(); }
            else if (peek() && (peek().t === "num" || peek().t === "id" || (peek().t === "op" && peek().v === "("))) { mathy = true; v *= power(); }  // 2pi, 3(4+1)
            else return v;
        }
    }
    function unary() {
        if (eat("-")) { mathy = true; return -unary(); }
        if (eat("+")) return unary();
        return power();
    }
    function power() {
        const base = atom();
        if (eat("^")) { mathy = true; return Math.pow(base, unary()); }
        return base;
    }
    function atom() {
        const t = peek();
        if (!t) fail();
        if (t.t === "num") { p++; return t.v; }
        if (t.t === "op" && t.v === "(") {
            p++; mathy = true;
            const v = expr();
            if (!eat(")")) fail();
            return v;
        }
        if (t.t === "id") {
            p++;
            if (FUNCS[t.v] && peek() && peek().t === "op" && peek().v === "(") {
                p++; mathy = true;
                const args = [];
                if (!eat(")")) { do { args.push(expr()); } while (eat(",")); if (!eat(")")) fail(); }
                return FUNCS[t.v].apply(null, args);
            }
            if (CONSTS[t.v] !== undefined) return CONSTS[t.v];
            fail();
        }
        fail();
    }

    try {
        const v = expr();
        if (p !== toks.length || !mathy || typeof v !== "number" || !isFinite(v)) return { ok: false };
        return { ok: true, value: v, text: format(v) };
    } catch (e) {
        return { ok: false };
    }
}

function format(v) {
    if (Number.isInteger(v) && Math.abs(v) < 1e15) return String(v);
    let s = Number(v.toPrecision(12)).toString();
    if (s.indexOf("e") < 0 && s.indexOf(".") >= 0) s = s.replace(/0+$/, "").replace(/\.$/, "");
    return s;
}
