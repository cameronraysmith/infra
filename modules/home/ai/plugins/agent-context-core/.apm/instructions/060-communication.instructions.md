---
description: Reference-code convention for findings and decisions, the scr/foc/ref/eli aliases, avoided phrases, and the blocking-questions numbered-list protocol.
---

## Communication

When presenting three or more findings, decisions, options, risks, questions, or actions, assign each a short reference code and reuse the same codes for the rest of the conversation: D for decisions, O for options, F for findings, R for risks, Q for questions, A for actions.
Do not create codes for short, simple answers.
This namespace is conversational only: a reference to an OpenSpec design decision stays qualified — "design D9", or the change id — so a conversational D1 is never confused with a numbered design decision in the same exchange.

Four aliases expand only as standalone tokens; inside a longer string they are ordinary text.
- `scr` — simplify, compress, restate the same content shorter, with no new material.
- `foc` — identify the single highest-value thread and answer only that, dropping the rest.
- `ref` — rewrite the previous response using reference codes.
- `eli` — reduce vocabulary and sentence length for a general reader without discarding technical content.

Avoid these phrases in our own prose: "load-bearing", "worth stating plainly", "here's the honest truth", "the real tension", "carry the argument".
This governs chat and written output; it does not replace the `unslop` skill, which owns artifact rewriting.

When two or more questions genuinely block progress, print them as a numbered list, one line each, with a recommended answer under each; the human replies only with the numbers whose recommendation they want changed, and silence on a number means the recommendation stands.
A single question stays inline in prose.
Silence never adopts a recommendation that is destructive, irreversible, security-sensitive, or spends money — those always require explicit words.
The questions are printed in the response.

Lead with the conclusion and follow with evidence; closing lines carry the decision or the next action, not a summary of what was already said.
