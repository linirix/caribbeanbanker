# CentralBanker Player Guide

`CentralBanker` is a strategy game about macroeconomic tradeoffs, not perfect control. You are trying to keep Solaverde stable enough that inflation, recession, reserve panic, and politics do not combine into failure.

## The Core Loop

Each quarter follows the same basic pattern:

1. Read the dashboard, recent news, and any cabinet or crisis prompts.
2. Decide whether to change:
   - `rate`
   - `reserve`
   - `controls`
   - `intervene`
   - `comm`
3. Use `preview` if you want a near-term staff forecast.
4. `advance`
5. Review `why`, `report`, `history`, and `news` to understand what moved.

## What You Are Managing

### Inflation

High inflation damages credibility, approval, and eventually political survival.

Ways to reduce it:
- raise `rate`
- keep communication credible
- avoid repeated currency weakness
- do not rely too heavily on emergency liquidity or fiscal drift

### Growth and Unemployment

Tight policy can restore order but also deepen recession.

Ways to support activity:
- lower `rate` when inflation risk allows it
- avoid unnecessary reserve panic
- use `measure liquidity` in genuine recession stress
- rebuild confidence so the private sector starts moving again

### Reserves and the Exchange Rate

Reserves are your buffer against external panic. If they collapse, your policy freedom collapses.

Ways to protect them:
- improve the current account over time
- tighten `controls` when capital flight becomes acute
- use `intervene` carefully
- use crisis tools when normal policy is no longer enough

### External Debt

External debt mainly falls when the external balance improves over time. Spending reserves alone does not pay it down.

Ways to lower it:
- improve the current account
- avoid repeated IMF dependence
- survive crises without letting deficits and refinancing risk spiral

### Credibility

Credibility is the game’s “do markets and the public believe you?” variable.

Ways to improve it:
- keep inflation under control
- communicate consistently with your actions
- avoid obvious panic and policy reversals
- meet the scenario’s central challenge rather than only chasing the score

## The Main Policy Tools

### `rate`

Your main anti-inflation and anti-overheating tool. It also affects growth, unemployment, and capital flows.

Use it when:
- inflation is rising
- expectations are drifting
- the currency is under pressure and credibility is weak

Do not expect it to solve every problem instantly.

### `reserve`

Reserve requirements are a secondary tightening tool. They help cool credit growth, but they are less central than the policy rate.

Use them when:
- credit is running too hot
- you want mild tightening without a full rate shock

### `controls`

Capital controls trade openness and approval for external stability.

Use them when:
- capital outflows are overwhelming reserves
- you need time to stop a run
- you are in or near an external-financing crisis

### `intervene`

Foreign-exchange intervention buys or spends reserves directly.

Use it when:
- you need to lean against a sudden currency move
- you are smoothing panic rather than trying to override fundamentals forever

### `comm`

Communication changes how your policy is interpreted.

Use it to reinforce the story your actual policy is telling. If your message and action diverge, credibility suffers.

## Crisis Tools

Use `crisis` to see what is currently available.

### `measure imf`

Best for:
- deep external-financing stress
- reserve exhaustion risk

Cost:
- debt, politics, growth pain

### `measure holiday`

Best for:
- acute run dynamics
- short-term panic containment

Cost:
- confidence damage and political pain

### `measure liquidity`

Best for:
- severe recession or credit freeze
- stabilizing demand when inflation danger is lower

Cost:
- inflation risk and credibility cost

## Good Habits

- Do not react mechanically to a single quarter.
- Use `preview`, but do not treat it as prophecy.
- Watch the interaction between inflation, credibility, reserves, and politics.
- Read the scenario goals carefully; in scenario mode, they are the real mandate.
- Use `why` after difficult quarters. It is often the fastest way to learn the model.

## Good First Scenarios

Recommended learning sequence:

1. `soft_landing_1966`
2. `oil_shock_1973`
3. `debt_workout_1984`
4. `recession_relief_1991`
5. `confidence_rebuild_1998`

These are designed to teach specific policy lessons rather than only throw maximum chaos at you.
