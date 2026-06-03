import requests
import logging

logger = logging.getLogger("dashboard")

class BTCTickerService:
    # Class-level cache to share price across dashboard instances or threads
    _cached_price = 104321.0
    _cached_change = 2.4

    def fetch_btc_price(self) -> dict:
        """
        Fetches the current Bitcoin price and 24h change percentage.
        Uses CoinGecko as primary, Binance as secondary, and falls back to cache.
        
        Returns: {
            "price": float,
            "change_pct": float,
            "price_str": str, (e.g. "$104,321")
            "change_str": str, (e.g. "+2.4%" or "-1.2%")
            "is_positive": bool
        }
        """
        # Tier 1: CoinGecko
        try:
            url = "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_24hr_change=true"
            response = requests.get(url, timeout=2.0)
            if response.status_code == 200:
                data = response.json()
                if "bitcoin" in data and "usd" in data["bitcoin"]:
                    price = float(data["bitcoin"]["usd"])
                    change = float(data["bitcoin"].get("usd_24h_change", 0.0))
                    BTCTickerService._cached_price = price
                    BTCTickerService._cached_change = change
                    return self._format_result(price, change)
        except Exception as e:
            logger.warning(f"CoinGecko API fetch failed, trying Binance: {e}")

        # Tier 2: Binance Fallback
        try:
            url = "https://api.binance.com/api/v3/ticker/24hr?symbol=BTCUSDT"
            response = requests.get(url, timeout=2.0)
            if response.status_code == 200:
                data = response.json()
                if "lastPrice" in data and "priceChangePercent" in data:
                    price = float(data["lastPrice"])
                    change = float(data["priceChangePercent"])
                    BTCTickerService._cached_price = price
                    BTCTickerService._cached_change = change
                    return self._format_result(price, change)
        except Exception as e:
            logger.warning(f"Binance API fetch failed, falling back to cache: {e}")

        # Tier 3: Memory Cache
        return self._format_result(BTCTickerService._cached_price, BTCTickerService._cached_change)

    def _format_result(self, price: float, change: float) -> dict:
        is_positive = change >= 0
        sign = "+" if is_positive else ""
        return {
            "price": price,
            "change_pct": change,
            "price_str": f"${price:,.0f}",
            "change_str": f"{sign}{change:.1f}%",
            "is_positive": is_positive
        }
