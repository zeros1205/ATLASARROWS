"""Fetches administrative boundary polygons for major world cities from
OSM Nominatim (1.1s between requests per usage policy; results cached).

Output: cities_raw.json  {city_en: {ko, geojson}}
"""
import json
import os
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "cities_raw.json")

CITIES = [
    ("Seoul, South Korea", "서울"), ("Busan, South Korea", "부산"),
    ("Tokyo, Japan", "도쿄"), ("Osaka, Japan", "오사카"),
    ("Beijing, China", "베이징"), ("Shanghai, China", "상하이"),
    ("Hong Kong", "홍콩"), ("Taipei, Taiwan", "타이베이"),
    ("Singapore", "싱가포르"), ("Bangkok, Thailand", "방콕"),
    ("Jakarta, Indonesia", "자카르타"), ("Manila, Philippines", "마닐라"),
    ("Hanoi, Vietnam", "하노이"), ("Ho Chi Minh City, Vietnam", "호치민"),
    ("Kuala Lumpur, Malaysia", "쿠알라룸푸르"),
    ("New Delhi, India", "뉴델리"), ("Mumbai, India", "뭄바이"),
    ("Dhaka, Bangladesh", "다카"), ("Karachi, Pakistan", "카라치"),
    ("Istanbul, Turkey", "이스탄불"), ("Dubai, United Arab Emirates", "두바이"),
    ("Riyadh, Saudi Arabia", "리야드"), ("Tehran, Iran", "테헤란"),
    ("Tel Aviv, Israel", "텔아비브"), ("Cairo, Egypt", "카이로"),
    ("Lagos, Nigeria", "라고스"), ("Nairobi, Kenya", "나이로비"),
    ("Johannesburg, South Africa", "요하네스버그"),
    ("Cape Town, South Africa", "케이프타운"),
    ("Casablanca, Morocco", "카사블랑카"),
    ("Moscow, Russia", "모스크바"), ("London, United Kingdom", "런던"),
    ("Paris, France", "파리"), ("Berlin, Germany", "베를린"),
    ("Munich, Germany", "뮌헨"), ("Madrid, Spain", "마드리드"),
    ("Barcelona, Spain", "바르셀로나"), ("Rome, Italy", "로마"),
    ("Milan, Italy", "밀라노"), ("Amsterdam, Netherlands", "암스테르담"),
    ("Brussels, Belgium", "브뤼셀"), ("Vienna, Austria", "빈"),
    ("Zurich, Switzerland", "취리히"), ("Stockholm, Sweden", "스톡홀름"),
    ("Oslo, Norway", "오슬로"), ("Copenhagen, Denmark", "코펜하겐"),
    ("Helsinki, Finland", "헬싱키"), ("Warsaw, Poland", "바르샤바"),
    ("Prague, Czech Republic", "프라하"), ("Budapest, Hungary", "부다페스트"),
    ("Athens, Greece", "아테네"), ("Lisbon, Portugal", "리스본"),
    ("Dublin, Ireland", "더블린"),
    ("New York City, USA", "뉴욕"), ("Los Angeles, USA", "로스앤젤레스"),
    ("Chicago, USA", "시카고"), ("San Francisco, USA", "샌프란시스코"),
    ("Seattle, USA", "시애틀"), ("Boston, USA", "보스턴"),
    ("Washington, District of Columbia, USA", "워싱턴 D.C."),
    ("Toronto, Canada", "토론토"), ("Vancouver, Canada", "밴쿠버"),
    ("Mexico City, Mexico", "멕시코시티"),
    ("Sao Paulo, Brazil", "상파울루"),
    ("Rio de Janeiro, Brazil", "리우데자네이루"),
    ("Buenos Aires, Argentina", "부에노스아이레스"),
    ("Santiago, Chile", "산티아고"), ("Lima, Peru", "리마"),
    ("Bogota, Colombia", "보고타"),
    ("Sydney, Australia", "시드니"), ("Melbourne, Australia", "멜버른"),
    ("Auckland, New Zealand", "오클랜드"),
]

UA = "z-arrows-level-research/0.1 (contact: jax1205@gmail.com)"


def fetch(q):
    url = ("https://nominatim.openstreetmap.org/search?"
           + urllib.parse.urlencode({
               "q": q, "format": "jsonv2", "limit": 5,
               "polygon_geojson": 1, "polygon_threshold": 0.002,
           }))
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as resp:
        results = json.load(resp)
    for res in results:
        gj = res.get("geojson", {})
        if gj.get("type") in ("Polygon", "MultiPolygon"):
            return gj, res.get("display_name", "")
    return None, None


def main():
    cache = {}
    if os.path.exists(CACHE):
        with open(CACHE, encoding="utf-8") as f:
            cache = json.load(f)
    for q, ko in CITIES:
        key = q.split(",")[0]
        if key in cache:
            continue
        try:
            gj, display = fetch(q)
        except Exception as e:
            print(f"ERR  {key}: {e}")
            time.sleep(1.1)
            continue
        if gj is None:
            print(f"MISS {key}: no polygon result")
        else:
            npts = json.dumps(gj).count("[")
            cache[key] = {"ko": ko, "geojson": gj, "display": display}
            print(f"OK   {key} ({npts} pts)")
        with open(CACHE, "w", encoding="utf-8") as f:
            json.dump(cache, f, ensure_ascii=False)
        time.sleep(1.1)
    print(f"\nDONE cached={len(cache)}/{len(CITIES)}")


if __name__ == "__main__":
    main()
