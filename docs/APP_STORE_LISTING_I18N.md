# 스토어 등록정보 다국어 번역 — Atlas Arrows

> `lib/l10n/`에 확정된 앱 지원 언어 7개(`AppLocalizations.supportedLocales`:
> de·en·es·fr·ja·ko·pt) 기준으로 App Store Connect / Play Console 등록정보를
> 언어별로 번역한 것. 한국어 원문(마스터)은 `docs/APP_STORE_LISTING.md` §1~2 및
> `docs/PLAY_STORE_LISTING.md` §1 — 이 문서는 그 마스터의 번역본이라 **문구를 고칠
> 땐 마스터부터 고치고 여기 반영할 것**.
>
> 2026-07-24: 기존 서브타이틀 "점묘 세계지도 캠페인"이 관용구로 부적절하다는 지적에 따라
> 동종 앱(Arrow Puzzle: Tap Away, Arrows – Puzzle Escape, Arrow Jam! 등) 문구를
> 분석해 전면 재작성했다. 동종 앱 공통 톤은 "relaxing", "no timer, just your brain",
> "tap, think, escape" — 저희는 여기에 **실제 국가 실루엣이 판이 된다**는, 동종 앱엔
> 없는 차별점을 얹었다. 화살표 생김새(꺾인 선) 얘기는 CLAUDE.md 명명 규칙대로 제목·
> 서브타이틀엔 안 넣고 설명 본문 첫 문단에만 남겼다.
>
> **같은 날 2차 개정** — 서브타이틀을 브랜드명 "Atlas Arrows"의 "atlas(지도책)"와 운을
> 맞춘 문구로 교체(사용자 제시안: EN `Tap arrows, tour the atlas.` / KO `화살 퍼즐을
> 탭하고, 세계를 탐험하세요.`). 나머지 언어도 "atlas"가 그대로 차용어인 점을 살려 같은
> 말장난 구조로 번역했다(de/fr/es/pt: atlas, ja: アトラス — 이미 설명 본문에서
> "アトラス・アローズ"로 쓰던 표기와 자연스럽게 이어짐). 아래 표의 서브타이틀 값만
> 이 개정으로 바뀌었고, 프로모션 텍스트·키워드·설명은 기존 그대로다.
>
> **같은 날 3차 개정** — 키워드를 사용자가 직접 제시한 EN 세트
> (`puzzle,arrow,arrows,brain,casual,map,atlas,tap,offline,nowifi,logic,game,
> teaser,iq,mind,travel,maze`, 99/100자)로 교체하고 전 언어 대응 번역. 글자수
> 제약 때문에 언어별로 일부만 뺐다 — DE/FR은 `iq`/`qi`(뇌 관련 단어 중복이라 판단)를
> 뺐고, 나머지 언어는 원본 17개 단어를 전부 넣었다. 서브타이틀·프로모션 텍스트·설명은
> 이 개정 대상이 아니다.
>
> **앱 이름은 모든 로케일에서 동일** — `Atlas Arrows: Tap Puzzle` (브랜드명이라 번역하지 않음, Play 문서 §1과 동일 원칙).
> 로케일 코드: App Store Connect 기준. `es`는 `es-ES`, `pt`는 `pt-BR`로 가정
> (모바일 게임 시장 규모상 브라질이 포르투갈보다 커서 — 필요 시 `pt-PT`로 교체 가능,
> 어차피 pt-BR/pt-PT 어휘 차이는 이 정도 짧은 카피에선 거의 없음). `en`은 `en-US`.

---

## en (en-US)

| 항목 | 값 |
|---|---|
| 서브타이틀 (30자 이하) | `Tap arrows, tour the atlas.` (27자) |
| 프로모션 텍스트 (170자 이하) | 아래 (156자) |
| 키워드 (100자 이하) | 아래 (99자) |
| Play 짧은 설명 (80자 이하) | `Arrow escape puzzle — conquer 216 real countries, one tap at a time` (67자) |

### Promotional text
```
The only arrow puzzle where every level is a real country. No timer, no Wi-Fi — just tap, think, escape. Stuck? Grab a hint. In a rush? Remove it instantly.
```

### Keywords
```
puzzle,arrow,arrows,brain,casual,map,atlas,tap,offline,nowifi,logic,game,teaser,iq,mind,travel,maze
```

### Description
```
Not your typical arrow puzzle. In Atlas Arrows, arrows aren't single tiles — each one is a line bent across several cells, so a single tap can clear a whole chain at once. That's a feeling no other arrow puzzle gives you.

Tap an arrow and it slides straight ahead until it leaves the board. Run into another arrow and you lose a heart; clear every arrow and the stage is won! That's the whole rule — but finding the right order to tap never stops being satisfying.

◆ World Map Campaign
Conquer countries one by one, smallest to largest. From tiny island nations to sprawling continental giants, over 200 countries connect into one long campaign. Pick a country from the dotted world map, and its silhouette — or a city's — becomes the puzzle board.

◆ Play Anytime, No Pressure
No time limit, no internet connection required. One round in a spare minute, or many when you want to focus. Stuck? Check a hint for the next move, or instantly clear one arrow with a remove item.

◆ Ads & In-App Purchases
The entire game is free to play. Watch an ad for a free hint, or pick up extra hints, remove items, or an ad-free upgrade in the shop.

Tap. Escape. Next country.
```

---

## ja

| 항목 | 값 |
|---|---|
| 서브타이틀 (30자 이하) | `矢印をタップして、アトラスを巡ろう。` (18자) |
| 프로모션 텍스트 (170자 이하) | 아래 (82자) |
| 키워드 (100자 이하) | 아래 (70자) |
| Play 짧은 설명 (80자 이하) | `矢印タップ脱出パズル — 216の実在する国をタップで制覇` (29자) |

### プロモーションテキスト
```
実在する国の形がそのままパズル盤になる、唯一の矢印ゲーム。タイマーもネット接続も不要、いつでもどこでも一勝負。詰まったらヒント、急ぐなら除去アイテムで手軽にクリア。
```

### キーワード
```
パズル,矢印,矢,脳,カジュアル,地図,アトラス,タップ,オフライン,ノーワイファイ,ロジック,ゲーム,ティーザー,IQ,マインド,旅,迷路
```

### 説明
```
ありきたりの矢印パズルとは違います。アトラス・アローズの矢印は1マスのタイルではなく、複数マスを折れ曲がってつながった1本の線 — タップ一回でどれだけの区間を一気に空にできるか、その手応えは他にありません。

矢印をタップするとまっすぐ進み、盤面から脱出します。他の矢印にぶつかるとハートが減り、盤面上の矢印をすべて空にすればクリア!ルールはこれだけですが、どの順番でタップすればすべて脱出できるか読み解く面白さは尽きません。

◆ 世界地図キャンペーン
面積の小さい順に国をひとつずつ制覇しましょう。小さな島国から広大な大陸国家まで、200を超える国がラウンドとしてつながっています。点描で描かれた世界地図から国を選ぶと、その国や都市のシルエットがそのままパズル盤になります。

◆ 気軽に、いつでも
制限時間もなく、インターネット接続も不要です。すきま時間には1プレイ、集中したいときには何プレイでも。詰まったらヒントで次の一手を確認したり、除去アイテムで矢印をひとつ即座に消したりできます。

◆ 広告とアプリ内課金
全コンテンツを無料で楽しめます。広告を見るとヒントを無料で獲得でき、ヒント・除去アイテムの追加購入や広告除去はショップで選べます。

タップ。脱出。次の国へ。
```

---

## de (de-DE)

| 항목 | 값 |
|---|---|
| 서브타이틀 (30자 이하) | `Pfeile tippen, Atlas erkunden.` (30자) |
| 프로모션 텍스트 (170자 이하) | 아래 (157자) |
| 키워드 (100자 이하) | 아래 (98자) |
| Play 짧은 설명 (80자 이하) | `Pfeil-Tippspiel — erobere 216 echte Länder, ein Tipp nach dem anderen` (69자) |

### Werbetext
```
Das einzige Pfeilpuzzle mit echten Ländern als Level. Kein Timer, kein WLAN — nur tippen, denken, entkommen. Hinweis bei Blockade, Sofort-Entfernen bei Eile.
```

### Schlüsselwörter
```
puzzle,pfeil,gehirn,casual,karte,atlas,tippen,offline,logik,spiel,teaser,verstand,reisen,labyrinth
```

### Beschreibung
```
Kein gewöhnliches Pfeilpuzzle. Bei Atlas Arrows sind Pfeile keine einzelnen Kacheln, sondern jeweils eine Linie, die sich über mehrere Felder biegt — ein einziger Tipp kann gleich eine ganze Kette leeren. Dieses Gefühl bietet kein anderes Pfeilpuzzle.

Tippe einen Pfeil an, und er gleitet geradeaus, bis er das Feld verlässt. Blockiert er einen anderen Pfeil, verlierst du ein Herz. Sind alle Pfeile weg, ist die Stage geschafft! Das sind schon alle Regeln – aber die richtige Reihenfolge zu finden, macht endlos Spaß.

◆ Weltkarten-Kampagne
Erobere ein Land nach dem anderen – von klein nach groß. Von winzigen Inselstaaten bis zu riesigen Kontinentalstaaten reihen sich über 200 Länder zu einer Kampagne. Wähle ein Land auf der gepunkteten Weltkarte, und seine Silhouette (oder die einer Stadt) wird zum Spielfeld.

◆ Jederzeit, ohne Druck
Kein Zeitlimit, keine Internetverbindung nötig. Mal eine Runde zwischendurch, mal mehrere am Stück. Steckst du fest, zeigt dir ein Hinweis den nächsten Zug, oder du entfernst mit einem Gegenstand sofort einen Pfeil.

◆ Werbung & In-App-Käufe
Der gesamte Inhalt ist kostenlos spielbar. Für einen kostenlosen Hinweis kannst du dir eine Werbung ansehen, zusätzliche Hinweise, Entfernen-Gegenstände und die Werbefreiheit gibt es im Shop.

Tippen. Entkommen. Nächstes Land.
```

---

## fr (fr-FR)

| 항목 | 값 |
|---|---|
| 서브타이틀 (30자 이하) | `Touchez les flèches, l'atlas.` (29자) |
| 프로모션 텍스트 (170자 이하) | 아래 (164자) |
| 키워드 (100자 이하) | 아래 (98자) |
| Play 짧은 설명 (80자 이하) | `Puzzle de flèches à tapoter — conquérez 216 vrais pays, un tap à la fois` (72자) |

### Texte promotionnel
```
Le seul puzzle de flèches où chaque niveau est un vrai pays. Sans minuteur ni Wi-Fi — tapotez, réfléchissez, échappez-vous. Indice si bloqué, suppression si pressé.
```

### Mots-clés
```
puzzle,flèche,cerveau,casual,carte,atlas,tap,horsligne,logique,jeu,teaser,esprit,voyage,labyrinthe
```

### Description
```
Pas un puzzle de flèches comme les autres. Dans Atlas Arrows, les flèches ne sont pas de simples cases : chacune est une ligne repliée sur plusieurs cases, si bien qu'un seul tap peut vider toute une chaîne d'un coup. Une sensation qu'aucun autre puzzle de flèches n'offre.

Touchez une flèche : elle avance tout droit jusqu'à sortir du plateau. Si elle percute une autre flèche, vous perdez un cœur. Videz le plateau de toutes ses flèches et le niveau est terminé ! C'est toute la règle — mais trouver le bon ordre pour tapoter est un plaisir sans fin.

◆ Campagne carte du monde
Conquérez les pays un par un, du plus petit au plus grand. Des minuscules îles-États aux vastes pays-continents, plus de 200 pays s'enchaînent en une seule campagne. Choisissez un pays sur la carte du monde en pointillés, et sa silhouette — ou celle d'une ville — devient le plateau de jeu.

◆ À tout moment, sans pression
Aucune limite de temps, aucune connexion internet nécessaire. Une partie sur un moment libre, ou plusieurs quand vous voulez vous concentrer. Bloqué ? Un indice vous montre le prochain coup, ou supprimez instantanément une flèche avec un objet dédié.

◆ Publicités et achats intégrés
Tout le contenu se joue gratuitement. Regardez une publicité pour un indice gratuit ; indices et objets de suppression supplémentaires, ainsi que la suppression des publicités, sont disponibles dans la boutique.

Tapez. Échappez-vous. Pays suivant.
```

---

## es (es-ES)

| 항목 | 값 |
|---|---|
| 서브타이틀 (30자 이하) | `Toca flechas, explora atlas.` (28자) |
| 프로모션 텍스트 (170자 이하) | 아래 (170자) |
| 키워드 (100자 이하) | 아래 (96자) |
| Play 짧은 설명 (80자 이하) | `Puzzle de flechas para tocar y escapar — conquista 216 países reales` (68자) |

### Texto promocional
```
El único puzzle de flechas donde cada nivel es un país real. Sin cronómetro ni Wi-Fi — solo toca, piensa, escapa. ¿Atascado? Una pista. ¿Con prisa? Elimínala al instante.
```

### Palabras clave
```
puzzle,flecha,cerebro,casual,mapa,atlas,tap,offline,logica,juego,teaser,ci,mente,viaje,laberinto
```

### Descripción
```
No es un puzzle de flechas cualquiera. En Atlas Arrows las flechas no son fichas de una sola casilla: cada una es una línea doblada a lo largo de varias casillas, así que un solo toque puede vaciar toda una cadena de golpe. Una sensación que ningún otro puzzle de flechas te da.

Toca una flecha y avanzará en línea recta hasta salir del tablero. Si choca con otra flecha, pierdes un corazón; vacía el tablero de flechas y superas la fase. Esas son todas las reglas, pero descubrir el orden correcto para tocar nunca deja de ser divertido.

◆ Campaña del mapa mundial
Conquista los países uno a uno, del más pequeño al más grande. Desde diminutas islas-nación hasta enormes países-continente, más de 200 países se encadenan en una sola campaña. Elige un país en el mapa mundial punteado y su silueta —o la de una ciudad— se convierte en el tablero.

◆ Cuando quieras, sin presión
Sin límite de tiempo ni conexión a internet. Una partida en un rato libre o varias cuando quieras concentrarte. Si te atascas, una pista te muestra el siguiente movimiento, o elimina una flecha al instante con un objeto especial.

◆ Anuncios y compras integradas
Todo el contenido se puede jugar gratis. Mira un anuncio para conseguir una pista gratis; pistas y objetos de eliminación adicionales, además de quitar los anuncios, están disponibles en la tienda.

Toca. Escapa. Siguiente país.
```

---

## pt (pt-BR)

| 항목 | 값 |
|---|---|
| 서브타이틀 (30자 이하) | `Toque setas, explore o atlas.` (29자) |
| 프로모션 텍스트 (170자 이하) | 아래 (167자) |
| 키워드 (100자 이하) | 아래 (94자) |
| Play 짧은 설명 (80자 이하) | `Puzzle de setas toque e escape — conquiste 216 países reais, um toque por vez` (77자) |

### Texto promocional
```
O único puzzle de setas em que cada fase é um país de verdade. Sem cronômetro, sem Wi-Fi — só tocar, pensar, escapar. Travou? Use uma dica. Com pressa? Remova na hora.
```

### Palavras-chave
```
puzzle,seta,cerebro,casual,mapa,atlas,tap,offline,logica,jogo,teaser,qi,mente,viagem,labirinto
```

### Descrição
```
Não é um puzzle de setas qualquer. Em Atlas Arrows, as setas não são peças de uma única casa: cada uma é uma linha dobrada ao longo de várias casas, então um único toque pode esvaziar uma cadeia inteira de uma vez. Uma sensação que nenhum outro puzzle de setas oferece.

Toque em uma seta e ela avança em linha reta até sair do tabuleiro. Se bater em outra seta, você perde um coração; esvazie o tabuleiro de todas as setas para vencer a fase! É essa a regra inteira, mas descobrir a ordem certa para tocar é uma diversão sem fim.

◆ Campanha do mapa-múndi
Conquiste os países um a um, do menor ao maior. De pequenas nações insulares a enormes países-continente, mais de 200 países se conectam em uma única campanha. Escolha um país no mapa-múndi pontilhado, e a silhueta dele — ou de uma cidade — vira o tabuleiro do quebra-cabeça.

◆ A qualquer hora, sem pressão
Sem limite de tempo, sem necessidade de internet. Uma partida numa folga rápida, ou várias quando quiser se concentrar. Travou? Uma dica mostra o próximo movimento, ou remova uma seta na hora com um item de remoção.

◆ Anúncios e compras no app
Todo o conteúdo pode ser jogado de graça. Assista a um anúncio para ganhar uma dica grátis; dicas e itens de remoção extras, além da remoção de anúncios, estão disponíveis na loja.

Toque. Escape. Próximo país.
```

---

## ko (참고 — 마스터, 번역본 아님)

한국어는 이 문서가 아니라 `docs/APP_STORE_LISTING.md`(App Store)와
`docs/PLAY_STORE_LISTING.md`(Play)가 원본이다. 값만 요약:

| 항목 | 값 |
|---|---|
| 서브타이틀 | `화살 퍼즐을 탭하고, 세계를 탐험하세요.` |
| 프로모션 텍스트 | `실제 나라 모양이 퍼즐 판이 되는 유일한 화살표 게임. 타이머도 인터넷도 필요 없이 언제 어디서든 한 판. 막히면 힌트, 급하면 제거 아이템으로 가볍게 클리어.` |
| 키워드 | `퍼즐,화살표,화살,두뇌,캐주얼,지도,아틀라스,탭,오프라인,와이파이없음,로직,게임,티저,아이큐,마인드,여행,미로` |
| Play 짧은 설명 | `화살표 탭 탈출 퍼즐 — 216개 진짜 나라를 탭으로 정복` |

---

## 적용 방법

- **App Store Connect**: 앱 레코드 › 로케일 추가(각 언어) › 위 서브타이틀/프로모션
  텍스트/키워드/설명을 해당 로케일 입력창에 그대로 붙여넣기. 앱 이름은 전 로케일 동일.
- **Play Console**: 스토어 등록정보 › 언어 추가 › 짧은 설명/전체 설명에 위 값 사용
  (Play는 서브타이틀·키워드 필드가 없음 — App Store 전용 필드).
- 각 필드 글자수는 이 문서 작성 시점에 Python `len()`으로 실측 검증했다(문자 수 기준,
  ASC/Play 콘솔이 표시하는 카운터와 대체로 일치하나 이모지·결합 문자가 섞이면 콘솔
  카운터가 다르게 셀 수 있으니 붙여넣은 뒤 콘솔 표시 카운터로 최종 확인할 것).
