extends RefCounted
## Статические данные игры: озёра, рыбы, удочки.

# --- Озёра ---------------------------------------------------------------
# scenery: forest | mountain | reed | winter | swamp | hot | tropical | autumn
# weather: none | snow | rain | leaves | fireflies | steam
const LAKES := [
	{"name": "Лесное озеро", "desc": "Тёплый закат над соснами. Щука и окунь.", "music": "res://audio/forest_lake.wav", "music_name": "Сосны у воды", "ambient": "forest",
		"water_deep": "#123e4d", "water_light": "#589a91", "sky_top": "#365b78", "sky_horizon": "#e6a579", "ground_bottom": "#142d38", "ground_horizon": "#88766e", "fog": "#c5947b", "sun": "#ffd3a0", "hill": "#354944", "sand": "#9b8062", "dock": "#8b6041", "dock_light": "#b17a50", "leaf_a": "#425b4b", "leaf_b": "#62724e", "pine_dark": "#263f39", "pine_light": "#34524a", "rock": "#68716a",
		"seed": 31415, "season": "ЗОЛОТАЯ ОСЕНЬ", "scenery": "forest", "weather": "none", "birds": true, "fog_density": 0.006, "fish": ["perch", "pike", "bream"]},
	{"name": "Горное озеро", "desc": "Хрустальный воздух и холодные вершины. Форель и хариус.", "music": "res://audio/mountain_lake.wav", "music_name": "Эхо вершин", "ambient": "mountain",
		"water_deep": "#13314d", "water_light": "#4785a2", "sky_top": "#244c73", "sky_horizon": "#a8cbd3", "ground_bottom": "#142936", "ground_horizon": "#647d83", "fog": "#9bbec3", "sun": "#d9efff", "hill": "#4a626b", "sand": "#7d9895", "dock": "#576e78", "dock_light": "#9ab5b6", "leaf_a": "#496954", "leaf_b": "#70856c", "pine_dark": "#234451", "pine_light": "#376778", "rock": "#8da4a7",
		"seed": 27182, "season": "ГОРНЫЙ РАССВЕТ", "scenery": "mountain", "weather": "none", "birds": true, "fog_density": 0.006, "fish": ["trout", "grayling", "char"]},
	{"name": "Тростниковый залив", "desc": "Тёплый туман и светлячки. Карась, линь и лещ.", "music": "res://audio/reed_bay.wav", "music_name": "Тихие камыши", "ambient": "reed",
		"water_deep": "#254c47", "water_light": "#87ad82", "sky_top": "#526d75", "sky_horizon": "#e5bd8d", "ground_bottom": "#253a35", "ground_horizon": "#958a72", "fog": "#c7ac83", "sun": "#ffe0a0", "hill": "#4b5b42", "sand": "#ad9364", "dock": "#786046", "dock_light": "#ba9760", "leaf_a": "#617546", "leaf_b": "#8a8a4f", "pine_dark": "#34473d", "pine_light": "#53664a", "rock": "#8b8a70",
		"seed": 16180, "season": "ЛЕТНЯЯ ЗАВОДЬ", "scenery": "reed", "weather": "fireflies", "birds": false, "fog_density": 0.007, "fish": ["crucian", "tench", "bream"]},
	{"name": "Зимнее озеро", "desc": "Тихий снегопад и льдины у берега. Сиг, налим, корюшка.", "music": "res://audio/winter_lake.wav", "music_name": "Первый снег", "ambient": "winter",
		"water_deep": "#15384f", "water_light": "#6fa6bf", "sky_top": "#5d7ea3", "sky_horizon": "#dfeaf2", "ground_bottom": "#3b4f63", "ground_horizon": "#c9d8e2", "fog": "#c3d3df", "sun": "#fff3e0", "hill": "#c9d8e3", "sand": "#dbe7ef", "dock": "#6d5a4d", "dock_light": "#9c8676", "leaf_a": "#e9f1f5", "leaf_b": "#cfe0e8", "pine_dark": "#2c4a4a", "pine_light": "#3f6764", "rock": "#8fa3ad",
		"seed": 41001, "season": "ТИХАЯ ЗИМА", "scenery": "winter", "weather": "snow", "ice": true, "birds": false, "fog_density": 0.010, "sun_energy": 1.0, "ambient_energy": 0.5, "fish": ["whitefish", "burbot", "smelt"]},
	{"name": "Лунное озеро", "desc": "Звёздная ночь и светлячки. Сом, угорь и жерех.", "music": "res://audio/moon_lake.wav", "music_name": "Лунная дорожка", "ambient": "night",
		"water_deep": "#07182d", "water_light": "#3b6796", "sky_top": "#0a1330", "sky_horizon": "#33456b", "ground_bottom": "#050a16", "ground_horizon": "#1c2942", "fog": "#1a2745", "sun": "#9fb7ff", "hill": "#16233a", "sand": "#4a5468", "dock": "#4a3a30", "dock_light": "#6e5744", "leaf_a": "#1f3a3a", "leaf_b": "#2a4a48", "pine_dark": "#0f2226", "pine_light": "#183238", "rock": "#4a5a6e",
		"seed": 52002, "season": "ПОЛНОЛУНИЕ", "scenery": "forest", "weather": "fireflies", "night": true, "moon": true, "birds": false, "fog_density": 0.007, "sun_energy": 0.55, "ambient_energy": 0.7, "fish": ["catfish", "eel", "asp"]},
	{"name": "Туманное болото", "desc": "Густой туман, кувшинки и лягушки. Вьюн, ротан, золотой карась.", "music": "res://audio/swamp_mist.wav", "music_name": "Туман над трясиной", "ambient": "swamp",
		"water_deep": "#1c3a2e", "water_light": "#6a8a52", "sky_top": "#5b6f62", "sky_horizon": "#c3c8a2", "ground_bottom": "#26332a", "ground_horizon": "#8a916c", "fog": "#a9b58f", "sun": "#f0e6b0", "hill": "#3f5236", "sand": "#7b7147", "dock": "#5b4a36", "dock_light": "#7f6a4b", "leaf_a": "#5a7a3a", "leaf_b": "#8ea04a", "pine_dark": "#2a3d2c", "pine_light": "#3f5a3a", "rock": "#6c7458",
		"seed": 63003, "season": "РАННЕЕ УТРО", "scenery": "swamp", "weather": "fireflies", "birds": false, "fog_density": 0.022, "fish": ["loach", "rotan", "gold_crucian"]},
	{"name": "Дождливая бухта", "desc": "Летний ливень, круги на воде и гроза. Судак, плотва и язь.", "music": "res://audio/rain_bay.wav", "music_name": "Шёпот дождя", "ambient": "rain",
		"water_deep": "#1a3342", "water_light": "#547689", "sky_top": "#3f4e5e", "sky_horizon": "#8d9ba3", "ground_bottom": "#1e2a33", "ground_horizon": "#5c6b70", "fog": "#7d8b91", "sun": "#b8c6d0", "hill": "#3a4b47", "sand": "#6f6f5f", "dock": "#4d4038", "dock_light": "#6d5a4b", "leaf_a": "#3f5a44", "leaf_b": "#587552", "pine_dark": "#22363a", "pine_light": "#2e4a4d", "rock": "#6f7c7d",
		"seed": 74004, "season": "ЛЕТНИЙ ЛИВЕНЬ", "scenery": "forest", "weather": "rain", "thunder": true, "birds": false, "fog_density": 0.014, "sun_energy": 0.55, "fish": ["zander", "roach", "ide"]},
	{"name": "Горячие источники", "desc": "Тёплая вода, пар и круглые каменные террасы. Тилапия, кои, золотая рыбка.", "music": "res://audio/hot_springs.wav", "music_name": "Тёплый пар", "ambient": "hot",
		"water_deep": "#1c6a78", "water_light": "#6fd1c4", "sky_top": "#3d6a93", "sky_horizon": "#f0c9a8", "ground_bottom": "#28353f", "ground_horizon": "#a58f7f", "fog": "#e6d1c0", "sun": "#ffe3b8", "hill": "#5a6a5a", "sand": "#c7b394", "dock": "#7f6650", "dock_light": "#a98a67", "leaf_a": "#5f7f52", "leaf_b": "#86a061", "pine_dark": "#2f4a42", "pine_light": "#456a5c", "rock": "#b3a58f",
		"seed": 85005, "season": "ТЁПЛЫЙ РАССВЕТ", "scenery": "hot", "weather": "steam", "birds": true, "fog_density": 0.008, "fish": ["tilapia", "koi", "goldfish"]},
	{"name": "Тропическая лагуна", "desc": "Бирюзовая вода, пальмы и чайки. Клоун, хирург и барракуда.", "music": "res://audio/tropical_lagoon.wav", "music_name": "Бирюзовый бриз", "ambient": "tropical",
		"water_deep": "#0c6a86", "water_light": "#46d6c9", "sky_top": "#2a7fd0", "sky_horizon": "#bfe9f2", "ground_bottom": "#1b5566", "ground_horizon": "#d9cfa5", "fog": "#b9e3ea", "sun": "#fff6d0", "hill": "#4c8a5a", "sand": "#efdcae", "dock": "#9a7648", "dock_light": "#c99c62", "leaf_a": "#2f8a4a", "leaf_b": "#56b04e", "pine_dark": "#1f6a3c", "pine_light": "#3f9a4a", "rock": "#b8ab8a",
		"seed": 96006, "season": "ВЕЧНОЕ ЛЕТО", "scenery": "tropical", "weather": "none", "birds": true, "fog_density": 0.003, "sun_energy": 1.6, "fish": ["clownfish", "surgeon", "barracuda"]},
	{"name": "Багряный лес", "desc": "Падающие листья и золотая вода. Радужная форель, голавль, лосось.", "music": "res://audio/crimson_forest.wav", "music_name": "Багряный вальс", "ambient": "autumn",
		"water_deep": "#3a3f3f", "water_light": "#c99a5f", "sky_top": "#5a6f8f", "sky_horizon": "#f2b884", "ground_bottom": "#3a2a24", "ground_horizon": "#a8794f", "fog": "#dca277", "sun": "#ffc890", "hill": "#6a3a2a", "sand": "#a8794f", "dock": "#6d4a34", "dock_light": "#9a6c46", "leaf_a": "#c0492a", "leaf_b": "#e0a02e", "pine_dark": "#5b2a20", "pine_light": "#8a3d24", "rock": "#7a6a5c",
		"seed": 17007, "season": "БАГРЯНАЯ ОСЕНЬ", "scenery": "autumn", "weather": "leaves", "birds": true, "fog_density": 0.007, "fish": ["rainbow", "chub", "salmon"]},
	{"name": "Северное сияние", "desc": "Полярная ночь, снег и небесные огни. Палия, нельма и осётр.", "music": "res://audio/aurora.wav", "music_name": "Небесные огни", "ambient": "aurora",
		"water_deep": "#08213a", "water_light": "#3f8fa8", "sky_top": "#050c22", "sky_horizon": "#1b3a5a", "ground_bottom": "#0a1424", "ground_horizon": "#3b5670", "fog": "#26405a", "sun": "#a8d8ff", "hill": "#c8d8e4", "sand": "#dbe8f0", "dock": "#4a3f3a", "dock_light": "#6e5f56", "leaf_a": "#dbe8f0", "leaf_b": "#b8ccd8", "pine_dark": "#14303a", "pine_light": "#1f4a52", "rock": "#7d92a0",
		"seed": 28008, "season": "ПОЛЯРНАЯ НОЧЬ", "scenery": "winter", "weather": "snow", "night": true, "aurora": true, "ice": true, "birds": false, "fog_density": 0.007, "sun_energy": 0.5, "ambient_energy": 0.75, "fish": ["palia", "nelma", "sturgeon"]},
]

# --- Рыбы ----------------------------------------------------------------
# rarity: 1 — обычная, 2 — необычная, 3 — редкая, 4 — легендарная
# Форма: len — длина, h — полувысота тела (доля длины), w — полуширина (доля h),
# c — где тело самое толстое (0..1), ped — толщина хвостового стебля, tail/tail_h — хвост,
# dors = [начало, конец, высота] спинного плавника, anal — анальный плавник, pat — узор.
const FISH := {
	"perch": {"name": "ОКУНЬ", "min": 0.2, "max": 2.2, "rarity": 1, "len": 0.55, "h": 0.15, "c": 0.38, "ped": 0.12, "tail": 0.24, "tail_h": 0.17, "dors": [0.30, 0.62, 0.11], "anal": [0.62, 0.78, 0.05],
		"body": "#6f8a3f", "belly": "#efe3a6", "fin": "#e0523d", "pat": "stripes", "pat_color": "#2c3a22", "note": "Полосатый хищник с красными плавниками"},
	"pike": {"name": "ЩУКА", "min": 0.8, "max": 9.0, "rarity": 2, "len": 1.25, "h": 0.075, "c": 0.55, "ped": 0.16, "tail": 0.16, "tail_h": 0.10, "dors": [0.70, 0.88, 0.07], "anal": [0.70, 0.88, 0.05], "snout": 1.0,
		"body": "#6a7d3c", "belly": "#e6e2b8", "fin": "#a9682f", "pat": "spots", "pat_color": "#e0d68a", "note": "Быстрая зубастая охотница"},
	"bream": {"name": "ЛЕЩ", "min": 0.5, "max": 5.5, "rarity": 1, "len": 0.75, "h": 0.24, "c": 0.42, "ped": 0.10, "tail": 0.22, "tail_h": 0.22, "dors": [0.36, 0.55, 0.09], "anal": [0.48, 0.90, 0.10],
		"body": "#9a8a5a", "belly": "#e9dfc0", "fin": "#7d7460", "pat": "none", "pat_color": "#000000", "note": "Высокий серебристо-бронзовый лещ"},
	"trout": {"name": "ФОРЕЛЬ", "min": 0.4, "max": 4.5, "rarity": 2, "len": 0.7, "h": 0.12, "c": 0.42, "ped": 0.13, "tail": 0.20, "tail_h": 0.14, "dors": [0.42, 0.56, 0.08], "anal": [0.68, 0.80, 0.05],
		"body": "#8a9a5a", "belly": "#f0e0b0", "fin": "#d09a55", "pat": "spots", "pat_color": "#b03a3a", "note": "Пятнистая красавица холодных вод"},
	"grayling": {"name": "ХАРИУС", "min": 0.3, "max": 3.0, "rarity": 1, "len": 0.62, "h": 0.11, "c": 0.4, "ped": 0.11, "tail": 0.22, "tail_h": 0.15, "dors": [0.34, 0.66, 0.20], "anal": [0.68, 0.80, 0.04],
		"body": "#7b7f96", "belly": "#d8d8e0", "fin": "#8a5fa8", "pat": "spots", "pat_color": "#3a3550", "note": "С огромным «парусом» на спине"},
	"char": {"name": "ГОЛЕЦ", "min": 0.3, "max": 3.5, "rarity": 3, "len": 0.6, "h": 0.12, "c": 0.4, "ped": 0.12, "tail": 0.20, "tail_h": 0.14, "dors": [0.42, 0.56, 0.08], "anal": [0.68, 0.80, 0.06],
		"body": "#4f6b6a", "belly": "#ee8a4a", "fin": "#f2d9c0", "pat": "spots", "pat_color": "#f3d5a0", "note": "Оранжевое брюшко и светлые крапинки"},
	"crucian": {"name": "КАРАСЬ", "min": 0.3, "max": 2.6, "rarity": 1, "len": 0.5, "h": 0.25, "c": 0.45, "ped": 0.12, "tail": 0.2, "tail_h": 0.18, "dors": [0.30, 0.66, 0.11], "anal": [0.68, 0.82, 0.08],
		"body": "#b59a52", "belly": "#efdca0", "fin": "#c9793f", "pat": "none", "pat_color": "#000000", "note": "Круглый золотистый карась"},
	"tench": {"name": "ЛИНЬ", "min": 0.5, "max": 5.0, "rarity": 2, "len": 0.62, "h": 0.17, "c": 0.5, "ped": 0.2, "tail": 0.16, "tail_h": 0.16, "dors": [0.45, 0.62, 0.08], "anal": [0.66, 0.80, 0.06],
		"body": "#5a6a3a", "belly": "#a8a070", "fin": "#4c5a34", "pat": "none", "pat_color": "#000000", "note": "Тёмно-зелёный «доктор» заводей"},
	"whitefish": {"name": "СИГ", "min": 0.4, "max": 3.8, "rarity": 1, "len": 0.66, "h": 0.12, "c": 0.4, "ped": 0.1, "tail": 0.22, "tail_h": 0.15, "dors": [0.42, 0.56, 0.08], "anal": [0.66, 0.78, 0.05],
		"body": "#a9b3b8", "belly": "#f4f6f4", "fin": "#8d989f", "pat": "none", "pat_color": "#000000", "note": "Серебристая рыба северных озёр"},
	"burbot": {"name": "НАЛИМ", "min": 0.8, "max": 7.0, "rarity": 2, "len": 0.95, "h": 0.085, "c": 0.3, "ped": 0.5, "tail": 0.10, "tail_h": 0.07, "dors": [0.28, 0.98, 0.06], "anal": [0.5, 0.98, 0.06], "barbel": 1.0,
		"body": "#6e6a3a", "belly": "#d8cf9a", "fin": "#5a5630", "pat": "spots", "pat_color": "#3a371d", "note": "Зимний налим с усиком на подбородке"},
	"smelt": {"name": "КОРЮШКА", "min": 0.05, "max": 0.5, "rarity": 1, "len": 0.36, "h": 0.07, "c": 0.4, "ped": 0.1, "tail": 0.2, "tail_h": 0.12, "dors": [0.5, 0.6, 0.06], "anal": [0.7, 0.82, 0.04],
		"body": "#9fb6a8", "belly": "#f0f4ee", "fin": "#b8c8c0", "pat": "none", "pat_color": "#000000", "note": "Маленькая и пахнет огурцом"},
	"catfish": {"name": "СОМ", "min": 2.0, "max": 18.0, "rarity": 3, "len": 1.4, "h": 0.1, "w": 1.5, "c": 0.22, "ped": 0.22, "tail": 0.09, "tail_h": 0.07, "dors": [0.30, 0.36, 0.04], "anal": [0.42, 0.98, 0.06], "barbel": 2.0,
		"body": "#40483a", "belly": "#b9b48a", "fin": "#33392c", "pat": "spots", "pat_color": "#5a6248", "note": "Ночной гигант с длинными усами"},
	"eel": {"name": "УГОРЬ", "min": 0.4, "max": 3.0, "rarity": 2, "len": 1.7, "h": 0.028, "w": 1.0, "c": 0.08, "ped": 0.9, "tail": 0.05, "tail_h": 0.03, "dors": [0.15, 0.97, 0.03], "anal": [0.3, 0.97, 0.03], "wave": 0.08,
		"body": "#3b4a3a", "belly": "#d6cf8a", "fin": "#2a352b", "pat": "none", "pat_color": "#000000", "note": "Скользкий и извилистый"},
	"asp": {"name": "ЖЕРЕХ", "min": 0.6, "max": 5.5, "rarity": 2, "len": 0.8, "h": 0.1, "c": 0.4, "ped": 0.1, "tail": 0.24, "tail_h": 0.2, "dors": [0.42, 0.55, 0.07], "anal": [0.62, 0.78, 0.06],
		"body": "#7f8a90", "belly": "#f0f0ee", "fin": "#c94b3b", "pat": "none", "pat_color": "#000000", "note": "Стремительный серебряный хищник"},
	"loach": {"name": "ВЬЮН", "min": 0.05, "max": 0.35, "rarity": 1, "len": 0.5, "h": 0.045, "w": 1.1, "c": 0.3, "ped": 0.55, "tail": 0.1, "tail_h": 0.08, "dors": [0.55, 0.68, 0.05], "anal": [0.75, 0.85, 0.03], "barbel": 1.0,
		"body": "#8f8a4f", "belly": "#e8dda0", "fin": "#a69a55", "pat": "spots", "pat_color": "#4a4526", "note": "Болотный вьюн с усиками"},
	"rotan": {"name": "РОТАН", "min": 0.1, "max": 0.9, "rarity": 1, "len": 0.42, "h": 0.16, "c": 0.35, "ped": 0.35, "tail": 0.16, "tail_h": 0.14, "dors": [0.4, 0.62, 0.08], "anal": [0.62, 0.8, 0.06],
		"body": "#5a5a32", "belly": "#a9a46a", "fin": "#6a6a3c", "pat": "spots", "pat_color": "#a09248", "note": "Жадный обитатель заросших прудов"},
	"gold_crucian": {"name": "ЗОЛОТОЙ КАРАСЬ", "min": 0.3, "max": 3.0, "rarity": 3, "len": 0.52, "h": 0.26, "c": 0.45, "ped": 0.12, "tail": 0.22, "tail_h": 0.2, "dors": [0.30, 0.66, 0.12], "anal": [0.68, 0.82, 0.09],
		"body": "#e8b23a", "belly": "#ffe6a0", "fin": "#f08a2a", "pat": "none", "pat_color": "#000000", "note": "Редкий карась цвета старого золота"},
	"zander": {"name": "СУДАК", "min": 0.8, "max": 8.0, "rarity": 2, "len": 0.95, "h": 0.085, "c": 0.4, "ped": 0.11, "tail": 0.2, "tail_h": 0.14, "dors": [0.34, 0.66, 0.10], "anal": [0.68, 0.80, 0.06],
		"body": "#6f7f6f", "belly": "#ece8d0", "fin": "#7a8676", "pat": "stripes", "pat_color": "#3a4438", "note": "Клыкастый хищник глубин"},
	"roach": {"name": "ПЛОТВА", "min": 0.1, "max": 1.2, "rarity": 1, "len": 0.36, "h": 0.15, "c": 0.4, "ped": 0.1, "tail": 0.22, "tail_h": 0.18, "dors": [0.42, 0.56, 0.08], "anal": [0.6, 0.78, 0.07],
		"body": "#8a9aa0", "belly": "#f2f4f0", "fin": "#e05a3a", "pat": "none", "pat_color": "#000000", "note": "Серебряная рыбка с красными глазами"},
	"ide": {"name": "ЯЗЬ", "min": 0.4, "max": 4.0, "rarity": 2, "len": 0.6, "h": 0.14, "c": 0.42, "ped": 0.11, "tail": 0.22, "tail_h": 0.18, "dors": [0.42, 0.56, 0.08], "anal": [0.62, 0.78, 0.07],
		"body": "#a08a55", "belly": "#f2e8c0", "fin": "#e07a3a", "pat": "none", "pat_color": "#000000", "note": "Золотистый язь в дождливую погоду"},
	"tilapia": {"name": "ТИЛАПИЯ", "min": 0.3, "max": 3.0, "rarity": 1, "len": 0.5, "h": 0.2, "c": 0.42, "ped": 0.13, "tail": 0.2, "tail_h": 0.16, "dors": [0.30, 0.70, 0.13], "anal": [0.68, 0.82, 0.07],
		"body": "#a56a72", "belly": "#f0d0c0", "fin": "#d06a7a", "pat": "stripes", "pat_color": "#7a3a48", "note": "Любит тёплую воду"},
	"koi": {"name": "КОИ", "min": 0.8, "max": 6.0, "rarity": 3, "len": 0.8, "h": 0.15, "c": 0.45, "ped": 0.14, "tail": 0.22, "tail_h": 0.2, "dors": [0.42, 0.6, 0.09], "anal": [0.7, 0.8, 0.06],
		"body": "#f2f0e6", "belly": "#ffffff", "fin": "#f0e0d0", "pat": "patches", "pat_color": "#e0522a", "note": "Праздничная японская красавица"},
	"goldfish": {"name": "ЗОЛОТАЯ РЫБКА", "min": 0.1, "max": 1.0, "rarity": 4, "len": 0.4, "h": 0.22, "c": 0.4, "ped": 0.12, "tail": 0.5, "tail_h": 0.45, "dors": [0.34, 0.66, 0.16], "anal": [0.62, 0.78, 0.1],
		"body": "#ffb62a", "belly": "#ffe08a", "fin": "#ff8a1f", "pat": "none", "pat_color": "#000000", "note": "Говорят, исполняет желания"},
	"clownfish": {"name": "РЫБА-КЛОУН", "min": 0.05, "max": 0.4, "rarity": 2, "len": 0.32, "h": 0.2, "c": 0.45, "ped": 0.14, "tail": 0.2, "tail_h": 0.15, "dors": [0.30, 0.68, 0.10], "anal": [0.68, 0.8, 0.06],
		"body": "#ff7a1f", "belly": "#ff8f3a", "fin": "#ff7a1f", "pat": "rings", "pat_color": "#fdfdf6", "note": "Оранжевая с белыми кольцами"},
	"surgeon": {"name": "СИНИЙ ХИРУРГ", "min": 0.2, "max": 1.5, "rarity": 2, "len": 0.45, "h": 0.28, "c": 0.45, "ped": 0.1, "tail": 0.24, "tail_h": 0.24, "dors": [0.22, 0.85, 0.12], "anal": [0.5, 0.88, 0.1],
		"body": "#2a6ad8", "belly": "#4a8af0", "fin": "#ffd23a", "pat": "spots", "pat_color": "#0a1a4a", "note": "Ярко-синяя рыба рифа"},
	"barracuda": {"name": "БАРРАКУДА", "min": 2.0, "max": 14.0, "rarity": 3, "len": 1.45, "h": 0.065, "c": 0.5, "ped": 0.14, "tail": 0.16, "tail_h": 0.11, "dors": [0.62, 0.74, 0.06], "anal": [0.72, 0.84, 0.05], "snout": 1.2,
		"body": "#6f8a9a", "belly": "#e8f0f0", "fin": "#4f6a78", "pat": "stripes", "pat_color": "#2f4250", "note": "Быстрая морская торпеда"},
	"rainbow": {"name": "РАДУЖНАЯ ФОРЕЛЬ", "min": 0.4, "max": 5.5, "rarity": 1, "len": 0.72, "h": 0.12, "c": 0.42, "ped": 0.13, "tail": 0.2, "tail_h": 0.14, "dors": [0.42, 0.56, 0.08], "anal": [0.68, 0.8, 0.05],
		"body": "#8aa06a", "belly": "#f2eadc", "fin": "#d08a70", "pat": "band", "pat_color": "#e0587a", "note": "С розовой радужной полосой"},
	"chub": {"name": "ГОЛАВЛЬ", "min": 0.4, "max": 4.5, "rarity": 2, "len": 0.62, "h": 0.14, "c": 0.4, "ped": 0.12, "tail": 0.22, "tail_h": 0.18, "dors": [0.42, 0.55, 0.08], "anal": [0.62, 0.76, 0.07],
		"body": "#6a7a52", "belly": "#e6e2c0", "fin": "#d0503a", "pat": "none", "pat_color": "#000000", "note": "С широкой головой, отсюда и имя"},
	"salmon": {"name": "ЛОСОСЬ", "min": 1.5, "max": 10.0, "rarity": 3, "len": 1.0, "h": 0.12, "c": 0.4, "ped": 0.12, "tail": 0.2, "tail_h": 0.15, "dors": [0.42, 0.56, 0.08], "anal": [0.66, 0.78, 0.06],
		"body": "#a04a44", "belly": "#e8b2a0", "fin": "#8a3a3a", "pat": "spots", "pat_color": "#3a2020", "note": "Багряный нерестовый лосось"},
	"palia": {"name": "ПАЛИЯ", "min": 0.6, "max": 5.0, "rarity": 2, "len": 0.7, "h": 0.12, "c": 0.4, "ped": 0.12, "tail": 0.2, "tail_h": 0.14, "dors": [0.42, 0.56, 0.08], "anal": [0.68, 0.8, 0.06],
		"body": "#3d6a80", "belly": "#f0863a", "fin": "#f2f0e6", "pat": "spots", "pat_color": "#d8e8a0", "note": "Арктическая красавица"},
	"nelma": {"name": "НЕЛЬМА", "min": 2.0, "max": 12.0, "rarity": 3, "len": 1.15, "h": 0.1, "c": 0.4, "ped": 0.11, "tail": 0.2, "tail_h": 0.15, "dors": [0.40, 0.54, 0.07], "anal": [0.68, 0.78, 0.05], "snout": 0.6,
		"body": "#b6c4cc", "belly": "#fafcfc", "fin": "#9db0b8", "pat": "none", "pat_color": "#000000", "note": "Белорыбица холодного севера"},
	"sturgeon": {"name": "ОСЁТР", "min": 5.0, "max": 30.0, "rarity": 4, "len": 1.9, "h": 0.07, "w": 1.4, "c": 0.35, "ped": 0.2, "tail": 0.18, "tail_h": 0.15, "dors": [0.72, 0.84, 0.06], "anal": [0.72, 0.84, 0.05], "snout": 1.6, "barbel": 1.5,
		"body": "#4d5a5f", "belly": "#e0dccb", "fin": "#3a464a", "pat": "plates", "pat_color": "#b8b5a0", "note": "Древний трофей. Настоящая легенда озера"},
}

const RARITY_NAMES := ["", "ОБЫЧНАЯ", "НЕОБЫЧНАЯ", "РЕДКАЯ", "ЛЕГЕНДАРНАЯ"]
const RARITY_COLORS := ["#ffffff", "#a9c0ba", "#7fd0a4", "#7fb6f0", "#ffcf5f"]
const RARITY_WEIGHT := [0, 60, 30, 12, 4]
const RARITY_REWARD := [0.0, 1.0, 1.4, 2.0, 3.5]

# --- Удочки --------------------------------------------------------------
# len — длина удилища в кадре, thick — толщина, reel_color — цвет катушки
const RODS := [
	{"name": "Бамбуковая поплавочная", "description": "Лёгкая и послушная. Хороша для спокойной рыбалки у берега.", "cast": 0.88, "reel": 0.25, "stress": 0.70, "max_weight": 2.8, "color": "#b79a5d", "price": 0, "len": 1.0, "thick": 0.036},
	{"name": "Универсальный спиннинг", "description": "Надёжный баланс дальнего заброса и уверенной тяги.", "cast": 1.0, "reel": 0.29, "stress": 0.90, "max_weight": 4.5, "color": "#503e35", "price": 0, "len": 1.0, "thick": 0.038},
	{"name": "Карповое удилище", "description": "Крепкий бланк и мягкая леска для крупной рыбы.", "cast": 1.14, "reel": 0.24, "stress": 0.62, "max_weight": 7.0, "color": "#39494e", "price": 0, "len": 1.06, "thick": 0.044},
	{"name": "Лайт-спиннинг «Искра»", "description": "Очень лёгкая снасть: быстро выматывает, но любит аккуратную игру.", "cast": 1.03, "reel": 0.36, "stress": 1.05, "max_weight": 3.6, "color": "#53a99e", "price": 420, "len": 0.92, "thick": 0.030},
	{"name": "Фидер «Тихая заводь»", "description": "Чувствительная вершинка и прочная оснастка для леща и линя.", "cast": 0.98, "reel": 0.30, "stress": 0.76, "max_weight": 5.4, "color": "#87935b", "price": 650, "len": 1.04, "thick": 0.040},
	{"name": "Морской кастинг «Прибой»", "description": "Длинное мощное удилище для дальнего заброса и сильной рыбы.", "cast": 1.28, "reel": 0.27, "stress": 0.82, "max_weight": 7.8, "color": "#397c9c", "price": 950, "len": 1.12, "thick": 0.048},
	{"name": "Трофейный карповик «Гигант»", "description": "Тяжёлое удилище с усиленным бланком для настоящих трофеев.", "cast": 1.20, "reel": 0.24, "stress": 0.60, "max_weight": 10.0, "color": "#8d5145", "price": 1400, "len": 1.10, "thick": 0.054},
	{"name": "Зимняя «Снежинка»", "description": "Короткая ледяная удочка: быстро подсекает и вываживает мелочь.", "cast": 0.80, "reel": 0.40, "stress": 1.00, "max_weight": 3.0, "color": "#cfe6f2", "price": 350, "len": 0.78, "thick": 0.030},
	{"name": "Нахлыстовая «Лист»", "description": "Гибкий и звонкий бланк. Прощает ошибки и мягко гасит рывки.", "cast": 1.05, "reel": 0.33, "stress": 0.72, "max_weight": 4.6, "color": "#9bbd6a", "price": 780, "len": 1.16, "thick": 0.028},
	{"name": "Тропический джиг «Волна»", "description": "Для быстрой рыбы тёплых морей: дальний заброс и крепкая тяга.", "cast": 1.22, "reel": 0.32, "stress": 0.78, "max_weight": 8.5, "color": "#2fb0c9", "price": 1200, "len": 1.10, "thick": 0.046},
	{"name": "Золотой карповик «Король»", "description": "Позолоченные кольца и почти неразрываемая снасть.", "cast": 1.25, "reel": 0.30, "stress": 0.55, "max_weight": 14.0, "color": "#e2b84a", "price": 2200, "len": 1.14, "thick": 0.056},
	{"name": "Легенда «Северное сияние»", "description": "Мерцающая снасть для самых больших трофеев озёр.", "cast": 1.35, "reel": 0.38, "stress": 0.50, "max_weight": 32.0, "color": "#9d7bea", "price": 3500, "len": 1.18, "thick": 0.058},
]

const MUSIC_TRACKS := ["Сосны у воды", "Эхо вершин", "Тихие камыши"]

static func lake_fish(lake_index: int) -> Array:
	var ids: Array = LAKES[lake_index]["fish"]
	return ids

static func pick_species(lake_index: int, rng: RandomNumberGenerator) -> String:
	var ids := lake_fish(lake_index)
	var total := 0
	for id in ids:
		total += RARITY_WEIGHT[int(FISH[id]["rarity"])]
	var roll := rng.randi_range(0, total - 1)
	for id in ids:
		roll -= RARITY_WEIGHT[int(FISH[id]["rarity"])]
		if roll < 0:
			return String(id)
	return String(ids[0])

static func roll_weight(id: String, rod_max: float, rng: RandomNumberGenerator) -> float:
	var f: Dictionary = FISH[id]
	var lo := float(f["min"])
	var hi := minf(float(f["max"]), maxf(rod_max, lo))
	# лёгкие рыбы попадаются чаще тяжёлых
	var r := rng.randf()
	return lerpf(lo, hi, r * r)
