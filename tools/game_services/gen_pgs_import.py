#!/usr/bin/env python3
"""Atlas Arrows — Play Games Services import-bundle generator.

Play Games Services has **no create API** (unlike Apple's App Store Connect).
The only bulk path is the Play Console's importer, which takes a **ZIP** of
headerless CSVs + 512x512 icon PNGs. This builds those ZIPs; upload once in the
console (Play Games Services ▸ Achievements ▸ Import achievements). After import
the console MINTS the ids (CgkI…) — paste them into game_services.dart.

Default locale is **en-US**; every app language (docs/… AppSettings.supported)
ships as a localization: ko ja zh de fr it pt ru es. Achievements = 6 continent
titles (all countries of a continent cleared) + 5 generic. Icons under
tools/game_services/icons/ are TEMPORARY placeholders — swap for real art.

Importer rule: **no commas** in any name/description (it splits on ','). The
validator enforces it across every locale.

No third-party deps:
  python3 tools/game_services/gen_pgs_import.py [--out DIR]
"""
import argparse
import csv
import os
import zipfile

_HERE = os.path.dirname(os.path.abspath(__file__))
_ICONS = os.path.join(_HERE, "icons")
_OUT = os.path.join(_HERE, "out")

DEFAULT_LOCALE = "en-US"
# App languages → Play Games locale codes. Default first.
LOCALES = ["en-US", "ko-KR", "ja-JP", "zh-CN", "de-DE", "fr-FR", "it-IT",
           "pt-BR", "ru-RU", "es-ES"]

# ── Achievements ─────────────────────────────────────────────────────────────
# key, points (×5 in [5,200], total ≤2000), icon, {locale: (Name, Description)}.
# Continent completion titles first, then the generic set. NO COMMAS anywhere.
ACHIEVEMENTS = [
    ("europe", 20, "cont_europe.png", {
        "en-US": ("Old World Pilgrim", "Clear all 50 countries in Europe."),
        "ko-KR": ("구대륙 순례자", "유럽 50개국을 모두 클리어하세요."),
        "ja-JP": ("旧大陸の巡礼者", "ヨーロッパの50カ国をすべてクリア。"),
        "zh-CN": ("旧大陆朝圣者", "通关欧洲全部50个国家。"),
        "de-DE": ("Pilger der Alten Welt", "Schließe alle 50 Länder Europas ab."),
        "fr-FR": ("Pèlerin du Vieux Continent", "Termine les 50 pays d'Europe."),
        "it-IT": ("Pellegrino del Vecchio Mondo", "Completa tutti i 50 paesi d'Europa."),
        "pt-BR": ("Peregrino do Velho Mundo", "Complete os 50 países da Europa."),
        "ru-RU": ("Паломник Старого Света", "Пройдите все 50 стран Европы."),
        "es-ES": ("Peregrino del Viejo Mundo", "Completa los 50 países de Europa."),
    }),
    ("asia", 20, "cont_asia.png", {
        "en-US": ("Silk Road Caravan", "Clear all 52 countries in Asia."),
        "ko-KR": ("실크로드 대상", "아시아 52개국을 모두 클리어하세요."),
        "ja-JP": ("シルクロードの隊商", "アジアの52カ国をすべてクリア。"),
        "zh-CN": ("丝绸之路商队", "通关亚洲全部52个国家。"),
        "de-DE": ("Seidenstraßen-Karawane", "Schließe alle 52 Länder Asiens ab."),
        "fr-FR": ("Caravane de la Route de la soie", "Termine les 52 pays d'Asie."),
        "it-IT": ("Carovana della Via della Seta", "Completa tutti i 52 paesi dell'Asia."),
        "pt-BR": ("Caravana da Rota da Seda", "Complete os 52 países da Ásia."),
        "ru-RU": ("Караван Шёлкового пути", "Пройдите все 52 страны Азии."),
        "es-ES": ("Caravana de la Ruta de la Seda", "Completa los 52 países de Asia."),
    }),
    ("africa", 25, "cont_africa.png", {
        "en-US": ("Savanna Crosser", "Clear all 55 countries in Africa."),
        "ko-KR": ("사바나 종단자", "아프리카 55개국을 모두 클리어하세요."),
        "ja-JP": ("サバンナの縦断者", "アフリカの55カ国をすべてクリア。"),
        "zh-CN": ("热带草原纵横者", "通关非洲全部55个国家。"),
        "de-DE": ("Savannen-Durchquerer", "Schließe alle 55 Länder Afrikas ab."),
        "fr-FR": ("Traverseur de la savane", "Termine les 55 pays d'Afrique."),
        "it-IT": ("Attraversatore della savana", "Completa tutti i 55 paesi dell'Africa."),
        "pt-BR": ("Desbravador da Savana", "Complete os 55 países da África."),
        "ru-RU": ("Покоритель саванны", "Пройдите все 55 стран Африки."),
        "es-ES": ("Cruzador de la sabana", "Completa los 55 países de África."),
    }),
    ("north_america", 15, "cont_north_america.png", {
        "en-US": ("New World Pioneer", "Clear all 31 countries in North America."),
        "ko-KR": ("신대륙 개척자", "북아메리카 31개국을 모두 클리어하세요."),
        "ja-JP": ("新大陸の開拓者", "北アメリカの31カ国をすべてクリア。"),
        "zh-CN": ("新大陆开拓者", "通关北美洲全部31个国家。"),
        "de-DE": ("Pionier der Neuen Welt", "Schließe alle 31 Länder Nordamerikas ab."),
        "fr-FR": ("Pionnier du Nouveau Monde", "Termine les 31 pays d'Amérique du Nord."),
        "it-IT": ("Pioniere del Nuovo Mondo", "Completa tutti i 31 paesi del Nord America."),
        "pt-BR": ("Pioneiro do Novo Mundo", "Complete os 31 países da América do Norte."),
        "ru-RU": ("Первопроходец Нового Света", "Пройдите все 31 страну Северной Америки."),
        "es-ES": ("Pionero del Nuevo Mundo", "Completa los 31 países de América del Norte."),
    }),
    ("south_america", 10, "cont_south_america.png", {
        "en-US": ("Andes Climber", "Clear all 13 countries in South America."),
        "ko-KR": ("안데스 등정자", "남아메리카 13개국을 모두 클리어하세요."),
        "ja-JP": ("アンデスの登攀者", "南アメリカの13カ国をすべてクリア。"),
        "zh-CN": ("安第斯登山者", "通关南美洲全部13个国家。"),
        "de-DE": ("Anden-Bezwinger", "Schließe alle 13 Länder Südamerikas ab."),
        "fr-FR": ("Grimpeur des Andes", "Termine les 13 pays d'Amérique du Sud."),
        "it-IT": ("Scalatore delle Ande", "Completa tutti i 13 paesi del Sud America."),
        "pt-BR": ("Escalador dos Andes", "Complete os 13 países da América do Sul."),
        "ru-RU": ("Покоритель Анд", "Пройдите все 13 стран Южной Америки."),
        "es-ES": ("Escalador de los Andes", "Completa los 13 países de América del Sur."),
    }),
    ("oceania", 15, "cont_oceania.png", {
        "en-US": ("Southern Cross Navigator", "Clear all 15 countries in Oceania."),
        "ko-KR": ("남십자성 항해사", "오세아니아 15개국을 모두 클리어하세요."),
        "ja-JP": ("南十字星の航海士", "オセアニアの15カ国をすべてクリア。"),
        "zh-CN": ("南十字星领航员", "通关大洋洲全部15个国家。"),
        "de-DE": ("Navigator des Südkreuzes", "Schließe alle 15 Länder Ozeaniens ab."),
        "fr-FR": ("Navigateur de la Croix du Sud", "Termine les 15 pays d'Océanie."),
        "it-IT": ("Navigatore della Croce del Sud", "Completa tutti i 15 paesi dell'Oceania."),
        "pt-BR": ("Navegador do Cruzeiro do Sul", "Complete os 15 países da Oceania."),
        "ru-RU": ("Штурман Южного Креста", "Пройдите все 15 стран Океании."),
        "es-ES": ("Navegante de la Cruz del Sur", "Completa los 15 países de Oceanía."),
    }),
    ("first_clear", 5, "ach_first_clear.png", {
        "en-US": ("First Clear", "Clear your first stage."),
        "ko-KR": ("첫 클리어", "첫 스테이지를 클리어하세요."),
        "ja-JP": ("初クリア", "最初のステージをクリア。"),
        "zh-CN": ("首次通关", "通关第一个关卡。"),
        "de-DE": ("Erster Sieg", "Schließe deine erste Etappe ab."),
        "fr-FR": ("Première victoire", "Termine ta première étape."),
        "it-IT": ("Prima vittoria", "Completa la tua prima tappa."),
        "pt-BR": ("Primeira vitória", "Complete sua primeira fase."),
        "ru-RU": ("Первая победа", "Пройдите первый уровень."),
        "es-ES": ("Primera victoria", "Completa tu primera etapa."),
    }),
    ("first_country", 10, "ach_first_country.png", {
        "en-US": ("First Country", "Complete your first country."),
        "ko-KR": ("첫 국가", "첫 국가를 완주하세요."),
        "ja-JP": ("初めての国", "最初の国を制覇。"),
        "zh-CN": ("首个国家", "完成第一个国家。"),
        "de-DE": ("Erstes Land", "Schließe dein erstes Land ab."),
        "fr-FR": ("Premier pays", "Termine ton premier pays."),
        "it-IT": ("Primo paese", "Completa il tuo primo paese."),
        "pt-BR": ("Primeiro país", "Complete seu primeiro país."),
        "ru-RU": ("Первая страна", "Завершите первую страну."),
        "es-ES": ("Primer país", "Completa tu primer país."),
    }),
    ("stages_50", 15, "ach_stages_50.png", {
        "en-US": ("50 Stages", "Clear 50 stages in total."),
        "ko-KR": ("50 스테이지", "총 50 스테이지를 클리어하세요."),
        "ja-JP": ("50ステージ", "合計50ステージをクリア。"),
        "zh-CN": ("50 关", "累计通关50个关卡。"),
        "de-DE": ("50 Etappen", "Schließe insgesamt 50 Etappen ab."),
        "fr-FR": ("50 étapes", "Termine 50 étapes au total."),
        "it-IT": ("50 tappe", "Completa 50 tappe in totale."),
        "pt-BR": ("50 fases", "Complete 50 fases no total."),
        "ru-RU": ("50 уровней", "Пройдите 50 уровней всего."),
        "es-ES": ("50 etapas", "Completa 50 etapas en total."),
    }),
    ("stages_250", 25, "ach_stages_250.png", {
        "en-US": ("250 Stages", "Clear 250 stages in total."),
        "ko-KR": ("250 스테이지", "총 250 스테이지를 클리어하세요."),
        "ja-JP": ("250ステージ", "合計250ステージをクリア。"),
        "zh-CN": ("250 关", "累计通关250个关卡。"),
        "de-DE": ("250 Etappen", "Schließe insgesamt 250 Etappen ab."),
        "fr-FR": ("250 étapes", "Termine 250 étapes au total."),
        "it-IT": ("250 tappe", "Completa 250 tappe in totale."),
        "pt-BR": ("250 fases", "Complete 250 fases no total."),
        "ru-RU": ("250 уровней", "Пройдите 250 уровней всего."),
        "es-ES": ("250 etapas", "Completa 250 etapas en total."),
    }),
    ("flawless", 15, "ach_flawless.png", {
        "en-US": ("Flawless", "Clear a stage without losing a heart."),
        "ko-KR": ("무결점", "하트를 하나도 잃지 않고 클리어하세요."),
        "ja-JP": ("ノーミス", "ハートを一つも失わずにクリア。"),
        "zh-CN": ("完美通关", "不损失任何红心通关。"),
        "de-DE": ("Makellos", "Schließe eine Etappe ohne Herzverlust ab."),
        "fr-FR": ("Sans faute", "Termine une étape sans perdre de cœur."),
        "it-IT": ("Impeccabile", "Completa una tappa senza perdere cuori."),
        "pt-BR": ("Impecável", "Complete uma fase sem perder corações."),
        "ru-RU": ("Безупречно", "Пройдите уровень не потеряв сердец."),
        "es-ES": ("Impecable", "Completa una etapa sin perder corazones."),
    }),
]

# ── Leaderboards ─────────────────────────────────────────────────────────────
# key, sort order, score format, icon, {locale: Name}. Both are integer counts,
# higher = better. Play Games leaderboard import isn't always offered; the CSV
# then doubles as the manual-creation spec.
LEADERBOARDS = [
    ("stages", "LARGER_IS_BETTER", "NUMERIC", "lb_stages.png", {
        "en-US": "Stages Cleared", "ko-KR": "클리어한 스테이지", "ja-JP": "クリアしたステージ",
        "zh-CN": "已通关关卡", "de-DE": "Abgeschlossene Etappen", "fr-FR": "Étapes terminées",
        "it-IT": "Tappe completate", "pt-BR": "Fases concluídas", "ru-RU": "Пройдено уровней",
        "es-ES": "Etapas completadas",
    }),
    ("countries", "LARGER_IS_BETTER", "NUMERIC", "lb_countries.png", {
        "en-US": "Countries Completed", "ko-KR": "완주한 국가", "ja-JP": "制覇した国",
        "zh-CN": "已完成国家", "de-DE": "Abgeschlossene Länder", "fr-FR": "Pays terminés",
        "it-IT": "Paesi completati", "pt-BR": "Países concluídos", "ru-RU": "Завершено стран",
        "es-ES": "Países completados",
    }),
]


def _check_text(kind, key, locale, *fields):
    for t in fields:
        if "," in t:
            raise ValueError(f"comma not allowed [{kind} {key} {locale}]: {t!r}")
        if len(t) > 500:
            raise ValueError(f"text >500 chars [{kind} {key} {locale}]: {t!r}")


def _validate():
    total = 0
    names = set()
    for key, pts, icon, loc in ACHIEVEMENTS:
        if pts % 5 or not (5 <= pts <= 200):
            raise ValueError(f"points {pts} must be a multiple of 5 in [5,200]: {key}")
        total += pts
        if not os.path.exists(os.path.join(_ICONS, icon)):
            raise FileNotFoundError(f"icon missing: {icon}")
        for lc in LOCALES:
            if lc not in loc:
                raise ValueError(f"achievement {key} missing locale {lc}")
            name, desc = loc[lc]
            _check_text("ach", key, lc, name, desc)
        dn = loc[DEFAULT_LOCALE][0]
        if dn in names:
            raise ValueError(f"duplicate default name: {dn!r}")
        names.add(dn)
    if total > 2000:
        raise ValueError(f"total points {total} exceeds 2000")
    for key, _order, _fmt, icon, loc in LEADERBOARDS:
        if not os.path.exists(os.path.join(_ICONS, icon)):
            raise FileNotFoundError(f"icon missing: {icon}")
        for lc in LOCALES:
            if lc not in loc:
                raise ValueError(f"leaderboard {key} missing locale {lc}")
            _check_text("lb", key, lc, loc[lc])
    return total


def _write_csv(path, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        csv.writer(f, lineterminator="\n").writerows(rows)


def _zip(zip_path, csvs, icons):
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for name in csvs:
            z.write(os.path.join(_OUT, name), arcname=name)
        for icon in icons:
            src = os.path.join(_ICONS, icon)
            if os.path.getsize(src) >= 1_000_000:
                raise ValueError(f"icon >=1MB (zip limit): {icon}")
            z.write(src, arcname=icon)


def generate(out_dir):
    global _OUT
    _OUT = out_dir
    os.makedirs(_OUT, exist_ok=True)
    total = _validate()

    # ── Achievements ─────────────────────────────────────────────────────────
    # Metadata (default locale): Name,Description,Incremental,Steps,State,Points,ListOrder
    meta = []
    icon_map = []
    loc_rows = []
    for i, (_key, pts, icon, loc) in enumerate(ACHIEVEMENTS, start=1):
        name, desc = loc[DEFAULT_LOCALE]
        meta.append([name, desc, "False", "", "Revealed", pts, i])
        icon_map.append([name, icon])
        for lc in LOCALES:
            if lc == DEFAULT_LOCALE:
                continue
            lname, ldesc = loc[lc]
            loc_rows.append([name, lname, ldesc, lc])
    _write_csv(os.path.join(_OUT, "AchievementsMetadata.csv"), meta)
    _write_csv(os.path.join(_OUT, "AchievementsLocalizations.csv"), loc_rows)
    _write_csv(os.path.join(_OUT, "AchievementsIconsMappings.csv"), icon_map)
    ach_zip = os.path.join(_OUT, "AtlasArrowsAchievementsImport.zip")
    _zip(ach_zip,
         ["AchievementsMetadata.csv", "AchievementsLocalizations.csv",
          "AchievementsIconsMappings.csv"],
         [a[2] for a in ACHIEVEMENTS])

    # ── Leaderboards (attempt) ───────────────────────────────────────────────
    # Metadata: Name,ScoreOrder,ScoreFormat,ListOrder ; Localizations: Name,LocName,locale
    lb_meta, lb_icon, lb_loc = [], [], []
    for i, (_key, order, fmt, icon, loc) in enumerate(LEADERBOARDS, start=1):
        name = loc[DEFAULT_LOCALE]
        lb_meta.append([name, order, fmt, i])
        lb_icon.append([name, icon])
        for lc in LOCALES:
            if lc == DEFAULT_LOCALE:
                continue
            lb_loc.append([name, loc[lc], lc])
    _write_csv(os.path.join(_OUT, "LeaderboardsMetadata.csv"), lb_meta)
    _write_csv(os.path.join(_OUT, "LeaderboardsLocalizations.csv"), lb_loc)
    _write_csv(os.path.join(_OUT, "LeaderboardsIconsMappings.csv"), lb_icon)
    lb_zip = os.path.join(_OUT, "AtlasArrowsLeaderboardsImport.zip")
    _zip(lb_zip,
         ["LeaderboardsMetadata.csv", "LeaderboardsLocalizations.csv",
          "LeaderboardsIconsMappings.csv"],
         [b[3] for b in LEADERBOARDS])

    print(f"achievements: {len(ACHIEVEMENTS)}  ·  points {total}/2000  ·  "
          f"locales {len(LOCALES)} (default {DEFAULT_LOCALE})")
    print(f"  ZIP → {ach_zip}")
    print(f"leaderboards: {len(LEADERBOARDS)}")
    print(f"  ZIP → {lb_zip}")
    print()
    print("Upload in Play Console ▸ Play Games Services:")
    print("  • Achievements ▸ Import achievements → AtlasArrowsAchievementsImport.zip")
    print("  • Leaderboards: use the ZIP if the console offers import; else create")
    print("    the 2 boards manually from LeaderboardsMetadata.csv (+ localizations).")
    print("Then paste the console-issued CgkI… ids into game_services.dart.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=_OUT, help="output directory")
    generate(ap.parse_args().out)


if __name__ == "__main__":
    main()
