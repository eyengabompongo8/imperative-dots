.pragma library

/**
 * Fuzzy Search Engine for Snacks-style Window Picker
 * Provides fast fuzzy scoring, acronym matching, word boundary bonuses,
 * and highlighted HTML snippet generation.
 */

function fuzzyMatch(pattern, text) {
    if (!pattern || pattern.length === 0) {
        return { matched: true, score: 0, indices: [] };
    }
    if (!text || text.length === 0) {
        return { matched: false, score: -1, indices: [] };
    }

    let pLower = pattern.toLowerCase();
    let tLower = text.toLowerCase();

    // 1. Direct exact substring match gets large boost
    let exactIdx = tLower.indexOf(pLower);
    if (exactIdx !== -1) {
        let indices = [];
        for (let i = 0; i < pLower.length; i++) {
            indices.push(exactIdx + i);
        }
        let score = 1000 - exactIdx * 5 + (pLower.length === tLower.length ? 500 : 0);
        return { matched: true, score: score, indices: indices };
    }

    // 2. Sequential fuzzy match with bonuses
    let pLen = pLower.length;
    let tLen = tLower.length;
    let pIdx = 0;
    let indices = [];
    let score = 0;
    let consecutiveCount = 0;

    for (let tIdx = 0; tIdx < tLen && pIdx < pLen; tIdx++) {
        let pChar = pLower[pIdx];
        let tChar = tLower[tIdx];

        if (pChar === tChar) {
            indices.push(tIdx);
            pIdx++;

            let matchScore = 10;

            // Consecutive match bonus
            consecutiveCount++;
            matchScore += (consecutiveCount * 5);

            // Word boundary bonus (after space, dash, underscore, dot, slash or camelCase)
            if (tIdx === 0) {
                matchScore += 25; // First character bonus
            } else {
                let prevChar = text[tIdx - 1];
                if (prevChar === ' ' || prevChar === '-' || prevChar === '_' || prevChar === '.' || prevChar === '/') {
                    matchScore += 20;
                } else if (text[tIdx] !== tLower[tIdx] && prevChar === tLower[tIdx]) {
                    matchScore += 15; // CamelCase boundary
                }
            }

            score += matchScore;
        } else {
            consecutiveCount = 0;
        }
    }

    if (pIdx === pLen) {
        // Penalty for total span length (prefer tighter matches)
        let span = indices[indices.length - 1] - indices[0] + 1;
        score -= (span - pLen) * 2;
        return { matched: true, score: Math.max(1, score), indices: indices };
    }

    return { matched: false, score: -1, indices: [] };
}

/**
 * Multi-field scoring across Class Name, Window Title, and Workspace.
 */
function scoreWindow(query, win, mruIndex) {
    if (!query || query.trim().length === 0) {
        // Return default MRU recency score
        return {
            matched: true,
            score: 1000 - (mruIndex || 0) * 10,
            titleIndices: [],
            classIndices: []
        };
    }

    let q = query.trim();

    // Check workspace query shortcut e.g. "#2" or "ws 2" or "@1"
    if (q.startsWith("#") || q.startsWith("@")) {
        let wsTarget = q.slice(1).trim();
        if (wsTarget.length > 0) {
            let wsStr = win.workspaceId ? win.workspaceId.toString() : "";
            let wsNameStr = (win.workspaceName || "").toLowerCase();
            if (wsStr === wsTarget || wsNameStr.includes(wsTarget.toLowerCase())) {
                return {
                    matched: true,
                    score: 2000 - (mruIndex || 0),
                    titleIndices: [],
                    classIndices: []
                };
            }
        }
    }

    let classMatch = fuzzyMatch(q, win.className || "");
    let titleMatch = fuzzyMatch(q, win.title || "");
    let wsMatch = fuzzyMatch(q, (win.workspaceName || "") + " " + (win.workspaceId || ""));

    if (!classMatch.matched && !titleMatch.matched && !wsMatch.matched) {
        return { matched: false, score: -1, titleIndices: [], classIndices: [] };
    }

    let totalScore = 0;
    if (classMatch.matched) {
        totalScore += classMatch.score * 2.5; // App name is heavily weighted
    }
    if (titleMatch.matched) {
        totalScore += titleMatch.score * 1.5;
    }
    if (wsMatch.matched) {
        totalScore += wsMatch.score * 0.8;
    }

    // Small recency bonus
    totalScore -= (mruIndex || 0) * 2;

    return {
        matched: true,
        score: totalScore,
        titleIndices: titleMatch.matched ? titleMatch.indices : [],
        classIndices: classMatch.matched ? classMatch.indices : []
    };
}

/**
 * Helper to wrap matched character indices in HTML formatting for QML Text RichText
 */
function highlightText(text, indices, highlightColor) {
    if (!text) return "";
    if (!indices || indices.length === 0 || !highlightColor) {
        return escapeHtml(text);
    }

    let indexSet = {};
    for (let i = 0; i < indices.length; i++) {
        indexSet[indices[i]] = true;
    }

    let result = "";
    let isHighlighting = false;

    for (let i = 0; i < text.length; i++) {
        let char = text[i];
        let escaped = escapeHtml(char);

        if (indexSet[i]) {
            if (!isHighlighting) {
                result += "<font color='" + highlightColor + "'><b>";
                isHighlighting = true;
            }
            result += escaped;
        } else {
            if (isHighlighting) {
                result += "</b></font>";
                isHighlighting = false;
            }
            result += escaped;
        }
    }

    if (isHighlighting) {
        result += "</b></font>";
    }

    return result;
}

function escapeHtml(str) {
    if (!str) return "";
    return str.replace(/&/g, "&amp;")
              .replace(/</g, "&lt;")
              .replace(/>/g, "&gt;")
              .replace(/"/g, "&quot;")
              .replace(/'/g, "&#039;");
}
