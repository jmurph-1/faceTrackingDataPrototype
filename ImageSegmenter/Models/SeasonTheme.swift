import SwiftUI

struct SeasonTheme {
    let primaryColor: Color
    let paletteWhite: Color
    let accentColor: Color
    let accentColor2: Color
    let backgroundColor: Color
    let secondaryBackgroundColor: Color
    let textColor: Color
    let moduleColor: Color

    static func getTheme(for season: String, variation: Int = 0) -> SeasonTheme {
        let themes = allThemes[season] ?? softSummerThemes // Fallback to Soft Summer if season not found
        return themes[min(variation, themes.count - 1)]
    }

    // All themes organized by season
    static let allThemes: [String: [SeasonTheme]] = [
        "Soft Summer": softSummerThemes,
        "True Summer": trueSummerThemes,
        "Light Summer": lightSummerThemes, // Renamed from "Bright Summer" to "Light Summer" for consistency
        "Soft Autumn": softAutumnThemes,
        "True Autumn": trueAutumnThemes,
        "Dark Autumn": darkAutumnThemes,
        "Light Spring": lightSpringThemes,
        "True Spring": trueSpringThemes,
        "Bright Spring": brightSpringThemes,
        "Bright Winter": brightWinterThemes,
        "True Winter": trueWinterThemes,
        "Dark Winter": darkWinterThemes
    ]

    // Soft Summer Themes - Muted, Cool
    static let softSummerThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#739bbb"), // Ship Cove - Muted Blue
            paletteWhite: Color(hex: "#e4dcd1"), // Bizarre - Off-white neutral
            accentColor: Color(hex: "#a9b99f"), // Norway - Muted Green
            accentColor2: Color(hex: "#cd889a"), // Puce - Muted Rose
            backgroundColor: Color(hex: "#d8d1cd"), // Timberwolf - Light Greyish Beige
            secondaryBackgroundColor: Color(hex: "#4f6a93"), // Kashmir Blue - Deeper Muted Blue
            textColor: Color(hex: "#374550"), // Limed Spruce - Dark Cool Grey
            moduleColor: Color(hex: "#5c565b") // Chicago - Muted Dark Grey
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#b683a6"), // Amethyst Smoke - Muted Purple
            paletteWhite: Color(hex: "#dbddd1"), // Westar - Light Greenish Grey
            accentColor: Color(hex: "#77a680"), // Bay Leaf - Muted Green
            accentColor2: Color(hex: "#a2759b"), // Turkish Rose - Muted Rose-Purple
            backgroundColor: Color(hex: "#ad9b9b"), // Dusty Gray - Muted Taupe
            secondaryBackgroundColor: Color(hex: "#716f99"), // Kimberly - Muted Blue-Purple
            textColor: Color(hex: "#43464c"), // Gravel - Dark Grey
            moduleColor: Color(hex: "#696e6e") // Dove Gray - Medium Grey
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#78acc8"), // Danube - Muted Blue
            paletteWhite: Color(hex: "#d2c9c8"), // Swirl - Light Rosy Beige
            accentColor: Color(hex: "#893262"), // Vin Rouge - Muted Deep Berry
            accentColor2: Color(hex: "#a8c796"), // Feijoa - Muted Yellow-Green
            backgroundColor: Color(hex: "#aaafad"), // Silver Chalice - Muted Grey
            secondaryBackgroundColor: Color(hex: "#5d3955"), // Voodoo - Deep Muted Purple
            textColor: Color(hex: "#35465e"), // Pickled Bluewood - Dark Slate Blue
            moduleColor: Color(hex: "#7c797c") // Concord - Medium Grey
        )
    ]

    // True Summer Themes - Cool, Muted to Clear
    static let trueSummerThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#0172bb"), // Deep Cerulean - Clear Blue
            paletteWhite: Color(hex: "#e0dcdb"), // Bizarre - Off-white
            accentColor: Color(hex: "#3dc1cf"), // Turquoise - Clear Aqua
            accentColor2: Color(hex: "#ec5578"), // Wild Watermelon - Clear Pink
            backgroundColor: Color(hex: "#c1c2cb"), // Pumice - Light Cool Grey
            secondaryBackgroundColor: Color(hex: "#4682b4"), // Steel Blue - Medium Cool Blue
            textColor: Color(hex: "#3e4749"), // Cape Cod - Dark Cool Grey
            moduleColor: Color(hex: "#5a8bae") // Horizon - Muted Teal Blue
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#7d84bd"), // Wild Blue Yonder - Muted Lavender Blue
            paletteWhite: Color(hex: "#d9dde0"), // Geyser - Very Light Cool Grey
            accentColor: Color(hex: "#77a680"), // Bay Leaf - Muted Cool Green
            accentColor2: Color(hex: "#c67fae"), // Hopbush - Muted Cool Pink
            backgroundColor: Color(hex: "#bdbbd9"), // Blue Haze - Light Lavender Grey
            secondaryBackgroundColor: Color(hex: "#646194"), // Kimberly - Deeper Muted Lavender
            textColor: Color(hex: "#49454b"), // Gravel - Dark Cool Grey
            moduleColor: Color(hex: "#707f91") // Waterloo - Medium Slate Grey
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#488589"), // Smalt Blue - Muted Teal
            paletteWhite: Color(hex: "#b8c0d6"), // Heather - Light Bluish Grey
            accentColor: Color(hex: "#e9738e"), // Deep Blush - Clear Cool Pink
            accentColor2: Color(hex: "#54c6a9"), // De York - Clear Mint Green
            backgroundColor: Color(hex: "#8c91ab"), // Manatee - Medium Slate Grey
            secondaryBackgroundColor: Color(hex: "#246b63"), // Casal - Dark Teal
            textColor: Color(hex: "#374550"), // Limed Spruce - Darkest Cool Grey
            moduleColor: Color(hex: "#00a1b1") // Bondi Blue - Brighter Teal
        )
    ]

    // Light Summer Themes - Light, Cool, Delicate
    static let lightSummerThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#aedae6"), // Regent St Blue - Light Sky Blue
            paletteWhite: Color(hex: "#fef9cd"), // Lemon Chiffon - Pale Yellow White
            accentColor: Color(hex: "#caa0dc"), // Light Wisteria - Light Lavender
            accentColor2: Color(hex: "#ffbfce"), // Cotton Candy - Light Pink
            backgroundColor: Color(hex: "#e7e5da"), // Satin Linen - Very Light Beige
            secondaryBackgroundColor: Color(hex: "#659bcd"), // Danube - Medium Light Blue
            textColor: Color(hex: "#646f9d"), // Kimberly - Muted Medium Blue
            moduleColor: Color(hex: "#88ceeb") // Seagull - Light Clear Blue
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#b0dfe6"), // Spindle - Very Light Aqua Blue
            paletteWhite: Color(hex: "#f3c3cf"), // Pink - Pale Pink White
            accentColor: Color(hex: "#93e9be"), // Algae Green - Light Mint
            accentColor2: Color(hex: "#fd8faf"), // Tickle Me Pink - Light Bright Pink
            backgroundColor: Color(hex: "#d9dde2"), // Geyser - Light Cool Grey
            secondaryBackgroundColor: Color(hex: "#7d6fad"), // Deluge - Muted Lavender
            textColor: Color(hex: "#707f91"), // Waterloo - Medium Grey
            moduleColor: Color(hex: "#accdef") // Spindle - Light Periwinkle Blue
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#ec5578"), // Wild Watermelon - Brightest Light Pink
            paletteWhite: Color(hex: "#f0efeb"), // Soft Peach (from Bright Winter, good light neutral)
            accentColor: Color(hex: "#00af9f"), // Persian Green - Light Teal
            accentColor2: Color(hex: "#b284bd"), // Amethyst Smoke - Light Muted Purple
            backgroundColor: Color(hex: "#f8d1d3"), // Pastel Pink - Very Pale Pink
            secondaryBackgroundColor: Color(hex: "#dc3856"), // Brick Red - Deeper Pink
            textColor: Color(hex: "#6c5759"), // Zambezi - Muted Dark Rose Brown
            moduleColor: Color(hex: "#f3c3cf") // Pink (repeated for module)
        )
    ]

    // Soft Autumn Themes - Muted, Warm
    static let softAutumnThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#a79277"), // Donkey Brown - Muted Warm Beige
            paletteWhite: Color(hex: "#f0ead8"), // Parchment - Warm Off-white
            accentColor: Color(hex: "#77a680"), // Bay Leaf - Muted Olive Green
            accentColor2: Color(hex: "#b66e79"), // Coral Tree - Muted Terracotta Rose
            backgroundColor: Color(hex: "#dfd8ca"), // Moon Mist - Light Warm Grey Beige
            secondaryBackgroundColor: Color(hex: "#836647"), // Shadow - Muted Brown
            textColor: Color(hex: "#402b47"), // Matterhorn - Deep Muted Plum
            moduleColor: Color(hex: "#a08072") // Pharlap - Muted Rosy Brown
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#c3b181"), // Sorrell Brown - Muted Yellow Beige
            paletteWhite: Color(hex: "#f9f4e8"), // White Linen - Very Light Warm White
            accentColor: Color(hex: "#a9b99f"), // Norway - Muted Sage Green
            accentColor2: Color(hex: "#915c5e"), // Spicy Mix - Muted Deep Rose
            backgroundColor: Color(hex: "#e1dbc9"), // Bone - Light Warm Beige
            secondaryBackgroundColor: Color(hex: "#5b7248"), // Dingley - Muted Dark Olive
            textColor: Color(hex: "#604052"), // Eggplant - Deep Muted Purple Brown
            moduleColor: Color(hex: "#8e9879") // Gurkha - Muted Greenish Beige
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#78acc8"), // Danube - Muted Blue (can work for SA as a contrast)
            paletteWhite: Color(hex: "#f0eadc"), // Janna - Warm Off-white
            accentColor: Color(hex: "#c18182"), // Old Rose - Muted Rose
            accentColor2: Color(hex: "#447d6e"), // Faded Jade - Muted Teal Green
            backgroundColor: Color(hex: "#d6cca8"), // Akaroa - Muted Yellowish Beige
            secondaryBackgroundColor: Color(hex: "#4f6a93"), // Kashmir Blue - Deeper Muted Blue (contrast)
            textColor: Color(hex: "#5d3955"), // Voodoo - Deep Muted Plum
            moduleColor: Color(hex: "#578e90") // Smalt Blue - Muted Blue Green
        )
    ]

    // True Autumn Themes - Warm, Muted to Rich
    static let trueAutumnThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#a0522f"), // Paarl - Rich Terracotta Brown
            paletteWhite: Color(hex: "#f5f4de"), // Beige - Warm Off-white
            accentColor: Color(hex: "#7b7a3b"), // Pesto - Olive Green
            accentColor2: Color(hex: "#e3725d"), // Terracotta - Warm Coral Red
            backgroundColor: Color(hex: "#e0c993"), // Calico - Warm Golden Beige
            secondaryBackgroundColor: Color(hex: "#664223"), // Pickled Bean - Dark Brown
            textColor: Color(hex: "#430e09"), // Bulgarian Rose - Deepest Brown
            moduleColor: Color(hex: "#9b6616") // Corn Harvest - Rich Gold Brown
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#be5504"), // Rose of Sharon - Rich Burnt Orange
            paletteWhite: Color(hex: "#f4e1ae"), // Cape Honey - Light Golden Beige
            accentColor: Color(hex: "#507944"), // Dingley - Forest Green
            accentColor2: Color(hex: "#fb8073"), // Salmon - Peachy Red
            backgroundColor: Color(hex: "#d4ac8a"), // Tumbleweed - Medium Warm Beige
            secondaryBackgroundColor: Color(hex: "#81461c"), // Russet - Rich Reddish Brown
            textColor: Color(hex: "#4b2f27"), // Cowboy - Dark Brown
            moduleColor: Color(hex: "#b64110") // Rust - Reddish Orange
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#008080"), // Teal - Classic True Autumn Teal
            paletteWhite: Color(hex: "#dcc01a"), // Bird Flower - Golden Yellow
            accentColor: Color(hex: "#b97435"), // Copper - Warm Brown Orange
            accentColor2: Color(hex: "#a72a2b"), // Mexican Red - Deep Warm Red
            backgroundColor: Color(hex: "#b5b35d"), // Olive Green - Warm Green
            secondaryBackgroundColor: Color(hex: "#034322"), // Zuccini - Darkest Forest Green
            textColor: Color(hex: "#444139"), // Kelp - Dark Brownish Grey
            moduleColor: Color(hex: "#4b531e") // Saratoga - Deep Olive
        )
    ]

    // Dark Autumn Themes - Deep, Warm, Rich
    static let darkAutumnThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#D8AF66"), // ochre, muted yellow type
            paletteWhite: Color(hex: "#F2E1C1"), // Almond - Light Warm Beige
            accentColor: Color(hex: "#018381"), // Teal - Rich Teal
            accentColor2: Color(hex: "#CE5C5B"), // Pohutukawa - Deep Berry Red
            backgroundColor: Color(hex: "#EEDFCE"), // Coral Reef - Muted Warm Beige
            secondaryBackgroundColor: Color(hex: "#311432"), // eggplant - deep purple
            textColor: Color(hex: "#362f29"), // Thunder - Darkest Brown
            moduleColor: Color(hex: "#8D011F") // Olive green
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#619ea1"), // Gothic - Muted Teal
            paletteWhite: Color(hex: "#d4b48d"), // Tan - Medium Warm Beige
            accentColor: Color(hex: "#bacc82"), // Feijoa - Olive Green
            accentColor2: Color(hex: "#ce5c5c"), // Chestnut Rose - Muted Red
            backgroundColor: Color(hex: "#c39a6c"), // Antique Brass - Golden Brown
            secondaryBackgroundColor: Color(hex: "#01585f"), // Deep Sea Green - Dark Teal
            textColor: Color(hex: "#5b3e38"), // Congo Brown - Deep Warm Brown
            moduleColor: Color(hex: "#0f4c82") // Congress Blue - Deep Blue (as a dark neutral)
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#9b8b50"), // Barley Corn - Golden Olive
            paletteWhite: K.Colors.Palette.DarkAutumn.neutrals.lightest, // Almond - Using defined constant
            accentColor: Color(hex: "#004e38"), // Sherwood Green - Deep Forest Green
            accentColor2: Color(hex: "#9b111e"), // Tamarillo - Deep Red
            backgroundColor: Color(hex: "#c2b281"), // Sorrell Brown - Muted Gold Beige
            secondaryBackgroundColor: Color(hex: "#454c3a"), // Kelp - Dark Olive Green
            textColor: Color(hex: "#430e0a"), // Bulgarian Rose - Deepest Brown Red
            moduleColor: Color(hex: "#5a214e") // Bossanova - Deep Plum (as a dark accent)
        )
    ]

    // Light Spring Themes - Light, Warm, Bright
    static let lightSpringThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#7bb7db"), // Cornflower Blue - Light Clear Blue
            paletteWhite: Color(hex: "#fffff0"), // Ivory - Pure Light Yellow White
            accentColor: Color(hex: "#89d8c2"), // Monte Carlo - Light Mint Green
            accentColor2: Color(hex: "#fea6cb"), // Carnation Pink - Light Clear Pink
            backgroundColor: Color(hex: "#f7e7cf"), // Champagne - Light Peachy Beige
            secondaryBackgroundColor: Color(hex: "#7eb6fe"), // Cornflower Blue (variant)
            textColor: Color(hex: "#685a4f"), // Dorado - Muted Warm Brown
            moduleColor: Color(hex: "#ab6dc2") // Lavender - Light Purple
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#fed777"), // Golden Sand - Light Warm Yellow
            paletteWhite: Color(hex: "#efdc83"), // Flax - Pale Yellow
            accentColor: Color(hex: "#63ffcb"), // Aquamarine - Light Bright Aqua
            accentColor2: Color(hex: "#ff7f9d"), // Froly - Bright Coral Pink
            backgroundColor: Color(hex: "#fbd48b"), // Grandis - Light Peach Yellow
            secondaryBackgroundColor: Color(hex: "#f8c46d"), // Rob Roy - Warm Apricot
            textColor: Color(hex: "#5c5758"), // Chicago - Muted Warm Grey
            moduleColor: Color(hex: "#00ccce") // Robin's Egg Blue - Bright Turquoise
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#fea079"), // Macaroni and Cheese - Light Peach
            paletteWhite: Color(hex: "#fcceb2"), // Apricot Peach
            accentColor: Color(hex: "#ace2b0"), // Chinook - Light Leaf Green
            accentColor2: Color(hex: "#fe5b8e"), // French Rose - Bright Pink
            backgroundColor: Color(hex: "#ffcba4"), // Flesh - Pale Apricot
            secondaryBackgroundColor: Color(hex: "#fa827b"), // Salmon - Peachy Pink
            textColor: Color(hex: "#836647"), // Shadow - Muted Warm Brown
            moduleColor: Color(hex: "#ea6677") // Brink Pink - Coral Pink
        )
    ]

    // True Spring Themes - Warm, Clear, Bright
    static let trueSpringThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#01b6eb"), // Cerulean - Bright Clear Blue
            paletteWhite: Color(hex: "#f5f4de"), // Beige - Light Warm White
            accentColor: Color(hex: "#4cbb16"), // Christi - Bright Kelly Green
            accentColor2: Color(hex: "#ff7f9d"), // Froly - Bright Coral Pink
            backgroundColor: Color(hex: "#f1c64a"), // Ronchi - Bright Warm Yellow
            secondaryBackgroundColor: Color(hex: "#1460bd"), // Denim - Bright Medium Blue
            textColor: Color(hex: "#3f332b"), // Birch - Dark Warm Brown
            moduleColor: Color(hex: "#009e62") // Observatory - Bright Teal Green
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#ffbf01"), // Amber - Bright Golden Yellow
            paletteWhite: Color(hex: "#f9de85"), // Buff - Light Yellow
            accentColor: Color(hex: "#40b48b"), // Breaker Bay - Bright Mint Green
            accentColor2: Color(hex: "#fb7273"), // Brink Pink - Bright Coral Red
            backgroundColor: Color(hex: "#e6ab71"), // Porsche - Warm Apricot
            secondaryBackgroundColor: Color(hex: "#eaa222"), // Fuel Yellow - Rich Yellow Orange
            textColor: Color(hex: "#704d37"), // Shingle Fawn - Medium Warm Brown
            moduleColor: Color(hex: "#ff5a54") // Sunset Orange - Bright Red Orange
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#6f9b41"), // Glade Green - Bright Leaf Green
            paletteWhite: Color(hex: "#c3b181"), // Sorrell Brown - Light Golden Beige
            accentColor: Color(hex: "#ff6449"), // Persimmon - Bright Orange Red
            accentColor2: Color(hex: "#9966ce"), // Amethyst - Bright Purple
            backgroundColor: Color(hex: "#b5c04f"), // Celery - Bright Yellow Green
            secondaryBackgroundColor: Color(hex: "#598205"), // Vida Loca - Deep Lime Green
            textColor: Color(hex: "#714e38"), // Shingle Fawn (variant)
            moduleColor: Color(hex: "#01a93c") // Forest Green - Bright Green
        )
    ]

    // Bright Spring Themes - Bright, Warm-Neutral, Clear
    static let brightSpringThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#3399fd"), // Dodger Blue - Bright Blue
            paletteWhite: Color(hex: "#fefff0"), // Ivory - Brightest Yellow White
            accentColor: Color(hex: "#32cd32"), // Harlequin - Bright Green
            accentColor2: Color(hex: "#ff66cc"), // Orchid - Bright Pink Purple
            backgroundColor: Color(hex: "#fff34f"), // Gorse - Bright Lemon Yellow
            secondaryBackgroundColor: Color(hex: "#010180"), // Navy Blue - Deepest Blue
            textColor: Color(hex: "#262f30"), // Charade - Darkest Cool Grey
            moduleColor: Color(hex: "#786eca") // Blue Marguerite - Bright Lavender
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#01f0f1"), // Cyan / Aqua - Bright Aqua
            paletteWhite: Color(hex: "#f0eada"), // Parchment - Light Warm Beige
            accentColor: Color(hex: "#ff4041"), // Coral Red - Bright Red
            accentColor2: Color(hex: "#e1218b"), // Wild Strawberry - Bright Deep Pink
            backgroundColor: Color(hex: "#ffff30"), // Golden Fizz - Bright Yellow
            secondaryBackgroundColor: Color(hex: "#018380"), // Teal - Deep Bright Teal
            textColor: Color(hex: "#5b3e38"), // Congo Brown - Dark Warm Brown
            moduleColor: Color(hex: "#3fe1d1") // Turquoise - Bright Turquoise
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#f96714"), // Orange - Bright Orange
            paletteWhite: Color(hex: "#fec66e"), // Goldenrod - Bright Yellow Orange
            accentColor: Color(hex: "#009474"), // Observatory - Bright Teal Green
            accentColor2: Color(hex: "#e35c7c"), // Mandy - Bright Watermelon Pink
            backgroundColor: Color(hex: "#f5b31e"), // My Sin - Bright Golden Yellow
            secondaryBackgroundColor: Color(hex: "#ff0901"), // Red - Pure Bright Red
            textColor: Color(hex: "#503835"), // Congo Brown (variant)
            moduleColor: Color(hex: "#f94d01") // Vermilion - Bright Orange Red
        )
    ]

    // Bright Winter Themes - Bright, Cool-Neutral, Clear
    static let brightWinterThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#02cdff"), // Bright Turquoise - Electric Blue
            paletteWhite: Color(hex: "#f0efeb"), // Soft Peach - Pure White
            accentColor: Color(hex: "#51c777"), // Emerald - Bright Green
            accentColor2: Color(hex: "#ff77ff"), // Blush Pink - Bright Fuchsia Pink
            backgroundColor: Color(hex: "#d5f1fe"), // Mabel - Icy Light Blue
            secondaryBackgroundColor: Color(hex: "#0180ff"), // Dodger Blue - Deep Bright Blue
            textColor: Color(hex: "#29282f"), // Shark - Darkest Neutral Grey
            moduleColor: Color(hex: "#4266f4") // Royal Blue - Bright Royal Blue
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#f81793"), // Persian Rose - Bright Magenta
            paletteWhite: Color(hex: "#facffb"), // Pink Lace - Icy Pink
            accentColor: Color(hex: "#0bb9b5"), // Eastern Blue - Bright Teal
            accentColor2: Color(hex: "#ffd502"), // Gold - Bright Yellow
            backgroundColor: Color(hex: "#ffbdda"), // Cupid - Light Bright Pink
            secondaryBackgroundColor: Color(hex: "#b71b94"), // Medium Red Violet - Deep Fuchsia
            textColor: Color(hex: "#2b3143"), // Tuna - Dark Blue Grey
            moduleColor: Color(hex: "#da71d7") // Orchid - Bright Purple Pink
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#ff2401"), // Scarlet - Bright True Red
            paletteWhite: Color(hex: "#f3e7b2"), // Banana Mania - Icy Yellow
            accentColor: Color(hex: "#017970"), // Surfie Green - Deep Teal
            accentColor2: Color(hex: "#810082"), // Violet Eggplant - Deep Bright Purple
            backgroundColor: Color(hex: "#e1f700"), // Turbo - Bright Lime Yellow
            secondaryBackgroundColor: Color(hex: "#ee2a3a"), // Alizarin Crimson - Deep Bright Red
            textColor: Color(hex: "#0a0a0a"), // Cod Gray - True Black
            moduleColor: Color(hex: "#dd143f") // Crimson - Bright Crimson Red
        )
    ]

    // True Winter Themes - Cool, Clear, Deep/Bright
    static let trueWinterThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#44a5f1"), // Picton Blue - Clear Icy Blue
            paletteWhite: Color(hex: "#e0dcdb"), // Bizarre - Optic White
            accentColor: Color(hex: "#009b8d"), // Gossamer - Clear Teal Green
            accentColor2: Color(hex: "#e50a5f"), // Razzmatazz - Clear Fuchsia
            backgroundColor: Color(hex: "#b5e9ec"), // Powder Blue - Icy Light Blue
            secondaryBackgroundColor: Color(hex: "#4269e2"), // Royal Blue - Clear Royal Blue
            textColor: Color(hex: "#262a48"), // Cloud Burst - Deepest Blue Black
            moduleColor: Color(hex: "#2953be") // Cerulean Blue - Deep Clear Blue
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#6a3fa0"), // Royal Purple - Clear Purple
            paletteWhite: Color(hex: "#e7e6fb"), // Blue Chalk - Icy Lavender White
            accentColor: Color(hex: "#01a93c"), // Forest Green (from True Spring, but works as clear green)
            accentColor2: Color(hex: "#f64a8b"), // French Rose - Clear Bright Pink
            backgroundColor: Color(hex: "#977bb7"), // Lavender Purple - Icy Lavender
            secondaryBackgroundColor: Color(hex: "#483d8c"), // Gigas - Deep Indigo
            textColor: Color(hex: "#2a1f43"), // Port Gore - Deepest Purple Black
            moduleColor: Color(hex: "#604b8b") // Butterfly Bush - Medium Clear Purple
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#f1e331"), // Golden Fizz - Clear Lemon Yellow
            paletteWhite: Color(hex: "#ffdef4"), // Pink Lace - Icy Pink White
            accentColor: Color(hex: "#0c6f69"), // Mosque - Deep Teal
            accentColor2: Color(hex: "#cb1f7b"), // Cerise Red - Clear Deep Pink
            backgroundColor: Color(hex: "#efea97"), // Primrose - Icy Pale Yellow
            secondaryBackgroundColor: Color(hex: "#dd143f"), // Crimson - Clear True Red
            textColor: Color(hex: "#000000"), // Black - True Black
            moduleColor: Color(hex: "#9e1d32") // Merlot - Deep Clear Red
        )
    ]

    // Dark Winter Themes - Deep, Cool, Rich/Clear
    static let darkWinterThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#2d62a4"), // Astral - Deep Sapphire Blue
            paletteWhite: Color(hex: "#c0c0c0"), // Silver - Cool Grey White
            accentColor: Color(hex: "#018380"), // Teal - Rich Cool Teal
            accentColor2: Color(hex: "#df5286"), // Mulberry - Deep Cool Berry
            backgroundColor: Color(hex: "#c1c2cb"), // Pumice - Light Cool Grey
            secondaryBackgroundColor: Color(hex: "#0e4e93"), // Congress Blue - Deeper Sapphire
            textColor: Color(hex: "#3b2e39"), // Blackcurrant - Darkest Plum
            moduleColor: Color(hex: "#111e6c") // Lucky Point - Deepest Navy
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#8e4484"), // Strikemaster - Deep Cool Purple
            paletteWhite: Color(hex: "#bbb9d5"), // Lavender Gray - Icy Lavender Grey
            accentColor: Color(hex: "#01694f"), // Watercourse - Deep Forest Green
            accentColor2: Color(hex: "#c61d3a"), // Cardinal - Deep Cool Red
            backgroundColor: Color(hex: "#999999"), // Star Dust - Medium Cool Grey
            secondaryBackgroundColor: Color(hex: "#5a2149"), // Bossanova - Deepest Cool Plum
            textColor: Color(hex: "#2c262d"), // Shark - Darkest Cool Grey
            moduleColor: Color(hex: "#893262") // Vin Rouge - Deep Berry Purple
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#d4af41"), // Turmeric - Rich Antique Gold
            paletteWhite: Color(hex: "#f7cac9"), // Pink - Icy Cool Pink
            accentColor: Color(hex: "#01585f"), // Deep Sea Green - Darkest Teal
            accentColor2: Color(hex: "#9c1c31"), // Merlot - Deep Cool Burgundy
            backgroundColor: Color(hex: "#f0e79f"), // Golden Glow - Pale Icy Yellow
            secondaryBackgroundColor: Color(hex: "#9b6616"), // Corn Harvest - Deep Old Gold
            textColor: Color(hex: "#0a0a0a"), // Cod Gray - True Black
            moduleColor: Color(hex: "#8c0304") // Red Berry - Deepest Cool Red
        )
    ]
}

// K struct for color constants, to be expanded
struct K {
    struct Colors {
        struct Palette {
            struct DarkAutumn {
                struct neutrals {
                    static let lightest = Color(hex: "#efdece") // Almond
                    static let medium = Color(hex: "#cebbaa") // Coral Reef
                    static let darkest = Color(hex: "#362f29") // Thunder
                }
                struct baseColors {
                    static let teal = Color(hex: "#018381")
                    static let olive = Color(hex: "#566e3c")
                }
                struct accentColors {
                    static let berryRed = Color(hex: "#8d021f") // Pohutukawa
                    static let mutedRed = Color(hex: "#bc494e") // Chestnut
                }
            }
            // Add other seasons here...
        }
    }
}
