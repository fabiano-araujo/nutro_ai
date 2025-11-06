# NDJSON Implementation for Diet Agent

## Overview

The diet generation feature now uses **NDJSON (Newline Delimited JSON)** format for streaming responses. This allows the Flutter client to display meals progressively as they are generated, rather than waiting for the complete response.

## What is NDJSON?

NDJSON is a streaming data format where each line is a complete, valid JSON object. This is ideal for:
- Progressive rendering of results
- Large datasets that don't fit in memory
- Real-time streaming applications

## Backend Requirements

### Current Endpoint
- **URL**: `/ai/generate-text`
- **Method**: POST
- **Agent Type**: `diet`
- **Streaming**: Enabled

### Response Format

The backend should stream NDJSON lines where:
1. Each meal is sent as a separate line
2. The final line contains the total nutrition summary

#### Example NDJSON Response

```ndjson
{"type":"breakfast","time":"07:00","name":"Café da Manhã Energético","foods":[{"name":"Ovos mexidos","emoji":"🍳","amount":100,"unit":"g","calories":155,"protein":13,"carbs":1,"fat":11},{"name":"Pão integral","emoji":"🍞","amount":50,"unit":"g","calories":120,"protein":4,"carbs":20,"fat":2}],"mealTotals":{"calories":275,"protein":17,"carbs":21,"fat":13}}
{"type":"lunch","time":"12:30","name":"Almoço Completo","foods":[{"name":"Arroz integral","emoji":"🍚","amount":150,"unit":"g","calories":180,"protein":4,"carbs":38,"fat":2},{"name":"Frango grelhado","emoji":"🍗","amount":150,"unit":"g","calories":165,"protein":31,"carbs":0,"fat":3.5}],"mealTotals":{"calories":345,"protein":35,"carbs":38,"fat":5.5}}
{"type":"dinner","time":"19:00","name":"Jantar Leve","foods":[{"name":"Salada mista","emoji":"🥗","amount":200,"unit":"g","calories":50,"protein":2,"carbs":10,"fat":0.5},{"name":"Salmão grelhado","emoji":"🐟","amount":150,"unit":"g","calories":280,"protein":30,"carbs":0,"fat":17}],"mealTotals":{"calories":330,"protein":32,"carbs":10,"fat":17.5}}
{"totalNutrition":{"calories":950,"protein":84,"carbs":69,"fat":36},"date":"2025-11-06"}
```

### Meal Object Structure

Each meal line must be a valid JSON object with this structure:

```json
{
  "type": "breakfast|lunch|dinner|snack",
  "time": "HH:MM",
  "name": "Meal Name in Portuguese",
  "foods": [
    {
      "name": "Food name",
      "emoji": "🍽️",
      "amount": 100,
      "unit": "g|ml|unidade",
      "calories": 200,
      "protein": 10.0,
      "carbs": 20.0,
      "fat": 5.0
    }
  ],
  "mealTotals": {
    "calories": 200,
    "protein": 10.0,
    "carbs": 20.0,
    "fat": 5.0
  }
}
```

### Final Summary Line Structure

The last line must contain the total nutrition and date:

```json
{
  "totalNutrition": {
    "calories": 2000,
    "protein": 150.0,
    "carbs": 200.0,
    "fat": 60.0
  },
  "date": "YYYY-MM-DD"
}
```

## Implementation Guidelines for Backend

### 1. AI Prompt Configuration

The diet agent prompt should instruct the AI to return NDJSON format. The Flutter client already sends this instruction in the prompt:

```
IMPORTANT: Return in NDJSON format (Newline Delimited JSON). Each line must be a valid JSON object:
- First N lines: One meal per line
- Last line: Total nutrition summary
```

### 2. Stream Processing

The backend should:

1. **Stream AI Response**: Receive streaming response from AI provider (OpenRouter, Hyperbolic, etc.)
2. **Parse NDJSON Lines**: As complete lines arrive, validate they are valid JSON
3. **Send to Client**: Stream each validated line to the Flutter client via SSE (Server-Sent Events)

### 3. Server-Sent Events Format

The backend already uses SSE with this format:

```
data: {"text": "...ndjson line...", "done": false}

data: {"text": "...next ndjson line...", "done": false}

data: {"done": true}
```

For NDJSON, the `text` field should contain complete NDJSON lines.

### 4. Example Backend Implementation (Pseudocode)

```typescript
// In the diet agent handler
async function handleDietGeneration(prompt: string, stream: Response) {
  const aiStream = await openRouterAPI.stream(prompt);
  let lineBuffer = '';

  for await (const chunk of aiStream) {
    lineBuffer += chunk;

    // Check for complete lines
    const lines = lineBuffer.split('\n');

    // Keep last incomplete line in buffer
    lineBuffer = lines.pop() || '';

    // Send complete lines
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed) continue;

      try {
        // Validate JSON
        const json = JSON.parse(trimmed);

        // Send to client via SSE
        stream.write(`data: ${JSON.stringify({ text: trimmed, done: false })}\n\n`);
      } catch (e) {
        console.error('Invalid JSON line:', trimmed);
      }
    }
  }

  // Send final done signal
  stream.write(`data: ${JSON.stringify({ done: true })}\n\n`);
}
```

## Flutter Client Implementation

The Flutter client (`DietPlanProvider`) now:

1. **Buffers Incoming Chunks**: Accumulates stream chunks into a line buffer
2. **Splits on Newlines**: Detects complete lines ending with `}`
3. **Parses Each Line**: Attempts to parse each line as JSON
4. **Progressive Updates**: Calls `notifyListeners()` after each meal is parsed
5. **UI Updates Immediately**: The `PersonalizedDietScreen` rebuilds with each new meal

### Benefits

- **Better UX**: Users see meals appear one by one
- **Faster Perceived Performance**: First meal appears quickly
- **Lower Memory Usage**: No need to buffer entire response
- **Error Isolation**: If one meal fails to parse, others still work

## Testing

### Test Case 1: Generate Complete Diet Plan

**Expected Behavior:**
- User clicks "Gerar Plano de Dieta"
- First meal appears within 2-3 seconds
- Additional meals appear progressively
- Total nutrition summary updates at the end
- Loading indicator disappears when complete

### Test Case 2: Replace Single Meal

**Expected Behavior:**
- User clicks refresh icon on a meal
- New meal appears to replace the old one
- Total nutrition recalculates
- Loading indicator on that meal only

### Test Case 3: Handle Malformed Response

**Expected Behavior:**
- If AI returns invalid NDJSON, client logs error but continues
- Partial results are still shown
- Error message shown to user if no meals were generated

## Backward Compatibility

The implementation gracefully handles both formats:

1. **Old Format (single JSON object)**: Still works if AI returns complete JSON
2. **New Format (NDJSON)**: Progressive rendering when using NDJSON

The parser attempts to parse each line individually and falls back to extracting the largest JSON object if NDJSON parsing fails.

## Migration Checklist for Backend

- [ ] Update diet agent system prompt to request NDJSON format
- [ ] Implement line buffering in stream handler
- [ ] Add JSON validation for each line
- [ ] Test with different AI providers (OpenRouter, Hyperbolic, Google)
- [ ] Add logging for debugging NDJSON parsing issues
- [ ] Monitor error rates and adjust prompts if needed
- [ ] Consider adding retry logic for failed parses

## Performance Considerations

### Backend
- **CPU**: Minimal overhead for line splitting and JSON validation
- **Memory**: Lower memory usage (no need to buffer entire response)
- **Network**: Same bandwidth usage, but better chunking

### Frontend
- **Parsing**: `jsonDecode()` called once per meal (3-6 times) instead of once for entire response
- **UI Updates**: Multiple `notifyListeners()` calls trigger rebuilds
- **Memory**: Lower peak memory usage

## Monitoring

Suggested metrics to track:

1. **Time to First Meal**: Measure from request start to first meal displayed
2. **Time to Complete Plan**: Total generation time
3. **Parse Error Rate**: % of lines that fail JSON parsing
4. **User Satisfaction**: Track if users abandon before completion

## Troubleshooting

### Issue: No meals appearing

**Check:**
- Backend is sending NDJSON format (one line per meal)
- Each line is valid JSON
- Lines end with newline character `\n`
- No markdown code fences (```json)

### Issue: Meals appear all at once

**Check:**
- Backend is streaming responses (not buffering)
- SSE events are sent immediately, not batched
- Network throttling in dev tools

### Issue: Parse errors

**Check:**
- AI prompt clearly specifies NDJSON format
- No extra text before/after JSON objects
- JSON is properly escaped
- Unicode characters are valid

## Future Enhancements

1. **Meal-by-Meal Animations**: Animate each meal as it appears
2. **Progress Indicator**: Show "Generating meal 2 of 5..."
3. **Skeleton Loading**: Show meal card placeholders
4. **Optimistic UI**: Show placeholder meals while generating
5. **Cancellation**: Allow users to stop generation mid-stream
6. **Retry**: Auto-retry failed meal generations

## References

- [NDJSON Specification](http://ndjson.org/)
- [Server-Sent Events API](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events)
- [Flutter Provider Documentation](https://pub.dev/packages/provider)
