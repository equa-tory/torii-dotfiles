.pragma library

// Small fuzzy matcher for the launcher. score(query, text) -> -1 (no match) or a positive number, higher = better.
// Order of preference: exact > prefix > word-start > substring > subsequence.

function scoreOne(q, t) {
    if (q === "") return 0;
    if (t === q) return 1000;
    if (t.indexOf(q) === 0) return 900 - t.length * 0.1;

    const words = t.split(/[\s\-_.\/()]+/);
    for (let i = 0; i < words.length; i++)
        if (words[i].indexOf(q) === 0) return 800 - i * 10 - t.length * 0.1;

    const at = t.indexOf(q);
    if (at >= 0) return 600 - at - t.length * 0.1;

    // subsequence: every char of q appears in order; reward consecutive runs and word starts
    let ti = 0, score = 0, prev = -2;
    for (let qi = 0; qi < q.length; qi++) {
        let found = -1;
        for (let j = ti; j < t.length; j++) {
            if (t[j] === q[qi]) { found = j; break; }
        }
        if (found < 0) return -1;
        score += 10;
        if (found === prev + 1) score += 8;
        if (found === 0 || /[\s\-_.\/]/.test(t[found - 1])) score += 12;
        prev = found;
        ti = found + 1;
    }
    return 200 + score - t.length * 0.5;
}

// every whitespace separated token of the query must match somewhere in the text
function score(query, text) {
    const t = String(text || "").toLowerCase();
    const tokens = String(query || "").toLowerCase().split(/\s+/).filter(x => x.length);
    if (tokens.length === 0) return 0;
    let total = 0;
    for (const tok of tokens) {
        const s = scoreOne(tok, t);
        if (s < 0) return -1;
        total += s;
    }
    return total / tokens.length;
}

// best score over several (text, weight) fields
function scoreFields(query, fields) {
    let best = -1;
    for (const f of fields) {
        if (!f.text) continue;
        const s = score(query, f.text);
        if (s >= 0) best = Math.max(best, s * f.weight);
    }
    return best;
}
