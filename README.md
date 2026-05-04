# skroutz-cart

> **Warning:** This project is vibe-coded. It was written with AI assistance and has not been audited for correctness, security, or robustness. Use at your own risk.

Finds the cheapest way to buy everything in your [Skroutz](https://www.skroutz.gr) cart by picking the optimal combination of shops, accounting for per-shop shipping fees. It follows the following logic for shipping fees:
- Every suborder has no shipping fee if its total price is above €15
- Every suborder has a shipping fee of €2.50 if its total price is below €15

More complex pricing logic should be implemented in the future.

## How it works

1. Fetches the SKUs in your Skroutz cart.
2. For each SKU, retrieves all available shop offers.
3. Solves the shop-assignment optimisation problem: minimise total cost (item prices + shipping).
4. Prints the optimal assignment and optionally rebuilds your cart with the selected offers.

## Installation

```bash
gem install bundler
bundle install
```

Requires Ruby ≥ 3.0.

## Getting your session cookie

1. Open [skroutz.gr](https://www.skroutz.gr) and log in.
2. Open DevTools → Network tab → reload the page.
3. Click any request to `www.skroutz.gr` and copy the full `Cookie:` header value.
4. Paste it into `cookie.txt` (or pass it with `-c`).

> The cookie is only used for local requests; it is never sent anywhere else.

## Usage

```bash
# Using cookie.txt (auto-detected if present)
ruby skroutz_cart.rb

# Pass cookie inline
ruby skroutz_cart.rb -c "_helmet_couch=...; cf_clearance=..."

# Pass cookie from a file
ruby skroutz_cart.rb --cookie-file /path/to/cookie.txt

# Skip the interactive prompt and add to cart automatically
ruby skroutz_cart.rb --yes

# Dry-run: print the result and exit without touching the cart
ruby skroutz_cart.rb --no

# Choose the optimisation algorithm (default: dp)
ruby skroutz_cart.rb --algorithm bnb
```

### All options

| Flag | Short | Description |
|---|---|---|
| `--cookie STRING` | `-c` | Session cookie string |
| `--cookie-file FILE` | `-cf` | File containing the cookie string |
| `--algorithm dp\|bnb` | `-a` | Optimisation algorithm (default: `dp`) |
| `--yes` | `-y` | Automatically add the optimal cart |
| `--no` | `-n` | Print result and exit without changes |
| `--verbose` | `-v` | Verbose output |
| `--help` | `-h` | Show help |

## Algorithms

### Subset partition DP (`--algorithm dp`, default)

Splits SKUs into groups and finds the cheapest single-shop price for every possible subset, then uses dynamic programming over subset partitions to find the globally optimal assignment.

- Time complexity: O(S × 2ⁿ) pre-computation + O(3ⁿ) partition DP, where S = number of shops and n = number of distinct SKUs.
- Practical limit: up to ~20 SKUs runs in a few seconds.

### Branch-and-bound (`--algorithm bnb`)

Explicit tree search with pruning based on a lower-bound suffix array and definite shipping costs. Works well when most shops share few SKUs, keeping the effective branching factor low.

## Running tests

```bash
bundle exec rspec
# or
bundle exec rake
```

## Caching

HTTP responses are cached under `.cache/` to avoid redundant requests during repeated runs. The cache is never used for the live cart endpoint. To clear it:

```ruby
require_relative 'lib/skroutz_cart'
SkroutzCart::Cache.clear
```

Or simply delete the `.cache/` directory.
