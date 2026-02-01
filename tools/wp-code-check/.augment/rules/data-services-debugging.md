---
type: "always_apply"
---

## 🛠️ STANDARDIZED DATA ANALYSIS PATTERN

When any task requires analyzing output from external commands, APIs, or data streams (scrapers, logs, DB queries, APIs, etc.), follow this EXACT sequence if agent <-> human debugging is not working:

1. **Capture the data**: Run the command or curl call, piping output to `./data-stream.json` (always overwrite):
Example for WP-CLI/DB query
local-wp [installation name] db query "SELECT * FROM wp_posts LIMIT 50" > data-stream.json 2>&1

Example for scraper/API
curl -s "https://api.example.com/scraped-data" > data-stream.json

Example for logs
tail -n 100 /path/to/plugin.log | jq . > data-stream.json

text

2. **Display the raw output**: Immediately run `cat data-stream.json` so the full content appears in chat context.

3. **Analyze the file**:
- Infer the schema: List all fields, data types, and example values.
- Check quality: Flag missing/null values, outliers, duplicates, or anomalies.
- Summarize: Provide stats (counts, avg/min/max for numerics, unique values for categoricals).
- Recommend: Suggest validation rules, transformations, or fixes (e.g., Zod schema, SQL constraints).

4. **Iterate if needed**: If more data is required, repeat with updated parameters, always using `./data-stream.json`.

This ensures consistent, reproducible analysis across all data sources without manual copying.
Usage Examples
For scraper service:

text
Analyze the latest scraped data from my HTTP scraper endpoint.
1. curl -s "https://neochrome-timesheets.local/wp-json/scraper/v1/latest" > data-stream.json
2. cat data-stream.json
3. Follow the STANDARDIZED DATA ANALYSIS PATTERN above.
For generic log monitoring:

text
Monitor recent plugin activity.
1. tail -f -n 200 ~/Library/Application\ Support/Local/run/*/logs/php-error.log > data-stream.json 2>&1
2. cat data-stream.json
3. Analyze following the STANDARDIZED DATA ANALYSIS PATTERN.
For API service:

text
Check Stripe webhook data.
1. curl -s "https://dashboard.stripe.com/api/v1/events?limit=50" -H "Authorization: Bearer $STRIPE_KEY" > data-stream.json
2. cat data-stream.json
3. Analyze using the STANDARDIZED DATA ANALYSIS PATTERN.