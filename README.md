# Teksti-tv (Ruby terminal app)

Simple terminal app for browsing YLE Teletext pages.

## Setup

1. Create a `.env` file with your API credentials:

```
YLE_APP_ID=your_app_id
YLE_APP_KEY=your_app_key
```

Get your API keys from https://developer.yle.fi/

2. Run the app:

```
./tekstitv
```

## Disclaimer

This app has been developed fully using Codex.

## Notes

- The app displays page 100 on start.
- Type any 3-digit page number and press Enter to load it (API only on entry).
- Press `A` / `D` or left/right arrows for previous/next page.
- Press `ESC` to go back in history.
- Press `h` to jump to page 100.
- Press `q` to quit.
- If you see SSL errors, set `SSL_CERT_FILE` to a valid CA bundle path.
- Pages are cached in `cache/` to avoid API limits.
- All visited pages are cached in memory for back navigation.
- The bottom appendix comes from page 100 and is shown on every page.
