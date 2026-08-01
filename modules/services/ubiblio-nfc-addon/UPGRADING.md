# Upgrading uBiblio (with the NFC + Danacode/NLI addons applied)

`modules/services/ubiblio.nix` pins uBiblio to an exact commit via
`ubiblio-src`'s `rev`/`hash`, and layers two local addons on top of it in
the `ubiblio-src-patched` derivation:

- **NFC withdraw/return** (`ubiblio-nfc-addon/nfc.py`, `nfc_result.html`)
- **Danacode/NLI title-lookup fallback** (`nli_by_title_method.py`,
  `service_nli_additions.py`, `api_nli_route.py`,
  `nli_fallback_form.html`, `nli_fallback_script.html`)

## Nothing changes on its own

`rev`/`hash` are hardcoded, not "latest" — a routine `nixos-rebuild
switch` rebuilds the exact same pinned commit forever, patches and all,
until someone deliberately edits those two lines. No surprise breakage
from upstream changes landing silently.

## Bumping the version

1. Pick a new commit from `seanboyce/ubiblio`, update `rev` in
   `ubiblio-src`. Get its content hash the lazy way: set `hash = "";`,
   run `nixos-rebuild switch --flake .#nectar`, and Nix's hash-mismatch
   error will report the correct value — paste it in. (This is the same
   trick used the first time this was pinned.)
2. Run `nixos-rebuild switch --flake .#nectar`.

Two different things can happen, depending on which kind of patch trips:

### `substituteInPlace --replace-fail` patches — fail LOUD, at build time

These require an exact text match against specific upstream lines: the
`main.py` router wiring, the `vars.py` API-key line, the `api.py`
except-block, and the two template insertion points in `addisbn.html` /
`scanIsbn.html`.

If upstream changed any of those exact lines, **the build fails
immediately** with a clear error naming which `--replace-fail` didn't
find its target. This is fail-closed by design — you can't accidentally
end up running a version where a patch silently didn't apply. Fix: open
`modules/services/ubiblio.nix`, find the failing `old_str`, update it to
match the new upstream text, rebuild, repeat until clean.

### Pure-append patches — fail QUIET, only at runtime

The new route methods (`nfc.py`'s `/nfc/{bookId}`,
`nli_by_title_method.py`'s `nli_by_title`, etc.) are appended to the end
of existing files rather than matched against specific text, so they
don't break the *build* if upstream changes nearby code. The risk here
is a **silent name collision**: if a future uBiblio version happens to
add its own function/route with the same name we picked, the build
succeeds but you get a Python-level error (duplicate route, redefined
name) only when the service actually starts or that route is hit.

## After any successful rebuild

Manually re-test both addons once — a clean build doesn't guarantee
upstream didn't restructure something adjacent in a way that changed
behavior without tripping either patch mechanism:

- Tap an NFC tag (or hit `/nfc/{bookId}` directly) — confirm withdraw/
  return still toggles correctly.
- Scan/enter a non-ISBN code, confirm the "look up by title via NLI"
  fallback form still appears and successfully pre-fills a book.

## If this addon surface keeps growing

At some point (more addons, deeper changes) it may be worth switching
from this patch-on-pin approach to a proper fork of `seanboyce/ubiblio`
with the changes as normal source code, pinned via `fetchFromGitHub`
pointed at the fork instead of upstream. That trades Nix build errors
for `git rebase` conflict markers when upstream changes something we
touched — roughly a wash in effort, just a more git-native way of
hitting the same wall. Not necessary yet for two small, well-scoped
features.
