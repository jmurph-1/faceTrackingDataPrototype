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
        let themes = allThemes[season] ?? softSummerThemes
        return themes[min(variation, themes.count - 1)]
    }
    
    // All themes organized by season
    static let allThemes: [String: [SeasonTheme]] = [
        "Soft Summer": softSummerThemes,
        "True Summer": trueSummerThemes,
        "Light Summer": lightSummerThemes,
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
    
    // Soft Summer Themes
    static let softSummerThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#b5cfe6"),
            paletteWhite: Color(hex: "#ded5c8"),
            accentColor: Color(hex: "#77a680"),
            accentColor2: Color(hex: "#893262"),
            backgroundColor: Color(hex: "#d8d1cd"),
            secondaryBackgroundColor: Color(hex: "#4f6a93"),
            textColor: Color(hex: "#3d1321"),
            moduleColor: Color(hex: "#4f6a93")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#8996c6"),
            paletteWhite: Color(hex: "#e4dcd1"),
            accentColor: Color(hex: "#b683a6"),
            accentColor2: Color(hex: "#77a680"),
            backgroundColor: Color(hex: "#c1c2cb"),
            secondaryBackgroundColor: Color(hex: "#4f525d"),
            textColor: Color(hex: "#423e3d"),
            moduleColor: Color(hex: "#716f99")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#a2759b"),
            paletteWhite: Color(hex: "#d2c9c8"),
            accentColor: Color(hex: "#8c91ab"),
            accentColor2: Color(hex: "#a9b99f"),
            backgroundColor: Color(hex: "#c0b4ab"),
            secondaryBackgroundColor: Color(hex: "#5c565b"),
            textColor: Color(hex: "#374550"),
            moduleColor: Color(hex: "#5d3955")
        )
    ]
    
    // True Summer Themes
    static let trueSummerThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#8bcef0"),
            paletteWhite: Color(hex: "#e0dcdb"),
            accentColor: Color(hex: "#3dc1cf"),
            accentColor2: Color(hex: "#e892b8"),
            backgroundColor: Color(hex: "#c1c2cb"),
            secondaryBackgroundColor: Color(hex: "#4682b4"),
            textColor: Color(hex: "#3e4749"),
            moduleColor: Color(hex: "#5a8bae")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#7d84bd"),
            paletteWhite: Color(hex: "#d9dde0"),
            accentColor: Color(hex: "#77a680"),
            accentColor2: Color(hex: "#c67fae"),
            backgroundColor: Color(hex: "#bdbbd9"),
            secondaryBackgroundColor: Color(hex: "#646194"),
            textColor: Color(hex: "#49454b"),
            moduleColor: Color(hex: "#707f91")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#4691a3"),
            paletteWhite: Color(hex: "#b8c0d6"),
            accentColor: Color(hex: "#e9738e"),
            accentColor2: Color(hex: "#54c6a9"),
            backgroundColor: Color(hex: "#8c91ab"),
            secondaryBackgroundColor: Color(hex: "#246b63"),
            textColor: Color(hex: "#374550"),
            moduleColor: Color(hex: "#488589")
        )
    ]
    
    // Light Summer Themes
    static let lightSummerThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#99c4e1"),
            paletteWhite: Color(hex: "#e0dcdb"),
            accentColor: Color(hex: "#c8a2c8"),
            accentColor2: Color(hex: "#e6b1b7"),
            backgroundColor: Color(hex: "#d9dde0"),
            secondaryBackgroundColor: Color(hex: "#73c2fc"),
            textColor: Color(hex: "#3e4749"),
            moduleColor: Color(hex: "#8996c6")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#b8c0d6"),
            paletteWhite: Color(hex: "#f8d1d3"),
            accentColor: Color(hex: "#89d8c0"),
            accentColor2: Color(hex: "#b683a6"),
            backgroundColor: Color(hex: "#bdbbd9"),
            secondaryBackgroundColor: Color(hex: "#716f99"),
            textColor: Color(hex: "#49454b"),
            moduleColor: Color(hex: "#9a8aa4")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#fc8eaa"),
            paletteWhite: Color(hex: "#facffb"),
            accentColor: Color(hex: "#5dc8d8"),
            accentColor2: Color(hex: "#da71d7"),
            backgroundColor: Color(hex: "#ffbdda"),
            secondaryBackgroundColor: Color(hex: "#ff7f9d"),
            textColor: Color(hex: "#71617b"),
            moduleColor: Color(hex: "#ec5578")
        )
    ]
    
    // Soft Autumn Themes
    static let softAutumnThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#c3b181"),
            paletteWhite: Color(hex: "#f0ead8"),
            accentColor: Color(hex: "#a9b99f"),
            accentColor2: Color(hex: "#cd889a"),
            backgroundColor: Color(hex: "#dfd8ca"),
            secondaryBackgroundColor: Color(hex: "#836647"),
            textColor: Color(hex: "#685a4f"),
            moduleColor: Color(hex: "#a08072")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#a79277"),
            paletteWhite: Color(hex: "#f9f4e8"),
            accentColor: Color(hex: "#77a680"),
            accentColor2: Color(hex: "#b66e79"),
            backgroundColor: Color(hex: "#e1dbc9"),
            secondaryBackgroundColor: Color(hex: "#915c5e"),
            textColor: Color(hex: "#604052"),
            moduleColor: Color(hex: "#8e9879")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#78acc8"),
            paletteWhite: Color(hex: "#e7e5da"),
            accentColor: Color(hex: "#c59cb5"),
            accentColor2: Color(hex: "#8fc5b7"),
            backgroundColor: Color(hex: "#bbb798"),
            secondaryBackgroundColor: Color(hex: "#4f6a93"),
            textColor: Color(hex: "#5d3955"),
            moduleColor: Color(hex: "#578e90")
        )
    ]
    
    // True Autumn Themes
    static let trueAutumnThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#d5a173"),
            paletteWhite: Color(hex: "#f5f4de"),
            accentColor: Color(hex: "#9faa20"),
            accentColor2: Color(hex: "#e3725d"),
            backgroundColor: Color(hex: "#e0c993"),
            secondaryBackgroundColor: Color(hex: "#a0522f"),
            textColor: Color(hex: "#4b2f27"),
            moduleColor: Color(hex: "#9b6616")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#ffa301"),
            paletteWhite: Color(hex: "#f5dfb4"),
            accentColor: Color(hex: "#7bb369"),
            accentColor2: Color(hex: "#fa8183"),
            backgroundColor: Color(hex: "#e4bb9b"),
            secondaryBackgroundColor: Color(hex: "#b12222"),
            textColor: Color(hex: "#3f332b"),
            moduleColor: Color(hex: "#e35823")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#008080"),
            paletteWhite: Color(hex: "#dcc01a"),
            accentColor: Color(hex: "#b97435"),
            accentColor2: Color(hex: "#26619d"),
            backgroundColor: Color(hex: "#b5b35d"),
            secondaryBackgroundColor: Color(hex: "#034322"),
            textColor: Color(hex: "#430e09"),
            moduleColor: Color(hex: "#507944")
        )
    ]
    
    // Dark Autumn Themes
    static let darkAutumnThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#b59562"),
            paletteWhite: Color(hex: "#efdece"),
            accentColor: Color(hex: "#566e3c"),
            accentColor2: Color(hex: "#bc494e"),
            backgroundColor: Color(hex: "#cebbaa"),
            secondaryBackgroundColor: Color(hex: "#704d37"),
            textColor: Color(hex: "#362f29"),
            moduleColor: Color(hex: "#84563c")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#619ea1"),
            paletteWhite: Color(hex: "#d4b48d"),
            accentColor: Color(hex: "#bacc82"),
            accentColor2: Color(hex: "#ce5c5c"),
            backgroundColor: Color(hex: "#c39a6c"),
            secondaryBackgroundColor: Color(hex: "#01585f"),
            textColor: Color(hex: "#5b3e38"),
            moduleColor: Color(hex: "#018381")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#9b8b50"),
            paletteWhite: Color(hex: "#ebd3af"),
            accentColor: Color(hex: "#d68a58"),
            accentColor2: Color(hex: "#b35d8e"),
            backgroundColor: Color(hex: "#c2b281"),
            secondaryBackgroundColor: Color(hex: "#454c3a"),
            textColor: Color(hex: "#430e0a"),
            moduleColor: Color(hex: "#584d37")
        )
    ]
    
    // Light Spring Themes
    static let lightSpringThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#7eb6fe"),
            paletteWhite: Color(hex: "#fffff0"),
            accentColor: Color(hex: "#89d8c2"),
            accentColor2: Color(hex: "#fd8faf"),
            backgroundColor: Color(hex: "#f7e7cf"),
            secondaryBackgroundColor: Color(hex: "#7bb7db"),
            textColor: Color(hex: "#685a4f"),
            moduleColor: Color(hex: "#ab6dc2")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#fed777"),
            paletteWhite: Color(hex: "#efdc83"),
            accentColor: Color(hex: "#63ffcb"),
            accentColor2: Color(hex: "#ff7f9d"),
            backgroundColor: Color(hex: "#fbd48b"),
            secondaryBackgroundColor: Color(hex: "#f8c46d"),
            textColor: Color(hex: "#5c5758"),
            moduleColor: Color(hex: "#00ccce")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#fea079"),
            paletteWhite: Color(hex: "#fcceb2"),
            accentColor: Color(hex: "#ace2b0"),
            accentColor2: Color(hex: "#fe5b8e"),
            backgroundColor: Color(hex: "#ffcba4"),
            secondaryBackgroundColor: Color(hex: "#fa827b"),
            textColor: Color(hex: "#836647"),
            moduleColor: Color(hex: "#ff888e")
        )
    ]
    
    // True Spring Themes
    static let trueSpringThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#01b6eb"),
            paletteWhite: Color(hex: "#f5f4de"),
            accentColor: Color(hex: "#4cbb16"),
            accentColor2: Color(hex: "#ff7f9d"),
            backgroundColor: Color(hex: "#f1c64a"),
            secondaryBackgroundColor: Color(hex: "#1460bd"),
            textColor: Color(hex: "#3f332b"),
            moduleColor: Color(hex: "#009b8d")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#ffbf01"),
            paletteWhite: Color(hex: "#f9de85"),
            accentColor: Color(hex: "#40b48b"),
            accentColor2: Color(hex: "#fb7273"),
            backgroundColor: Color(hex: "#e6ab71"),
            secondaryBackgroundColor: Color(hex: "#eaa222"),
            textColor: Color(hex: "#704d37"),
            moduleColor: Color(hex: "#ff5a54")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#6f9b41"),
            paletteWhite: Color(hex: "#c3b181"),
            accentColor: Color(hex: "#ff6449"),
            accentColor2: Color(hex: "#9966ce"),
            backgroundColor: Color(hex: "#b5c04f"),
            secondaryBackgroundColor: Color(hex: "#598205"),
            textColor: Color(hex: "#714e38"),
            moduleColor: Color(hex: "#01a93c")
        )
    ]
    
    // Bright Spring Themes
    static let brightSpringThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#3399fd"),
            paletteWhite: Color(hex: "#fefff0"),
            accentColor: Color(hex: "#32cd32"),
            accentColor2: Color(hex: "#ff66cc"),
            backgroundColor: Color(hex: "#fff34f"),
            secondaryBackgroundColor: Color(hex: "#010180"),
            textColor: Color(hex: "#262f30"),
            moduleColor: Color(hex: "#786eca")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#01f0f1"),
            paletteWhite: Color(hex: "#f0eada"),
            accentColor: Color(hex: "#ff4041"),
            accentColor2: Color(hex: "#e1218b"),
            backgroundColor: Color(hex: "#ffff30"),
            secondaryBackgroundColor: Color(hex: "#018380"),
            textColor: Color(hex: "#5b3e38"),
            moduleColor: Color(hex: "#3fe1d1")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#f96714"),
            paletteWhite: Color(hex: "#fec66e"),
            accentColor: Color(hex: "#009474"),
            accentColor2: Color(hex: "#e35c7c"),
            backgroundColor: Color(hex: "#f5b31e"),
            secondaryBackgroundColor: Color(hex: "#ff0901"),
            textColor: Color(hex: "#503835"),
            moduleColor: Color(hex: "#f94d01")
        )
    ]
    
    // Bright Winter Themes
    static let brightWinterThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#02cdff"),
            paletteWhite: Color(hex: "#f0efeb"),
            accentColor: Color(hex: "#51c777"),
            accentColor2: Color(hex: "#ff77ff"),
            backgroundColor: Color(hex: "#d5f1fe"),
            secondaryBackgroundColor: Color(hex: "#0180ff"),
            textColor: Color(hex: "#29282f"),
            moduleColor: Color(hex: "#4266f4")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#f81793"),
            paletteWhite: Color(hex: "#facffb"),
            accentColor: Color(hex: "#0bb9b5"),
            accentColor2: Color(hex: "#ffd502"),
            backgroundColor: Color(hex: "#ffbdda"),
            secondaryBackgroundColor: Color(hex: "#b71b94"),
            textColor: Color(hex: "#2b3143"),
            moduleColor: Color(hex: "#da71d7")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#ff2401"),
            paletteWhite: Color(hex: "#f3e7b2"),
            accentColor: Color(hex: "#017970"),
            accentColor2: Color(hex: "#810082"),
            backgroundColor: Color(hex: "#e1f700"),
            secondaryBackgroundColor: Color(hex: "#ee2a3a"),
            textColor: Color(hex: "#0a0a0a"),
            moduleColor: Color(hex: "#dd143f")
        )
    ]
    
    // True Winter Themes
    static let trueWinterThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#44a5f1"),
            paletteWhite: Color(hex: "#e0dcdb"),
            accentColor: Color(hex: "#009b8d"),
            accentColor2: Color(hex: "#e50a5f"),
            backgroundColor: Color(hex: "#b5e9ec"),
            secondaryBackgroundColor: Color(hex: "#4269e2"),
            textColor: Color(hex: "#262a48"),
            moduleColor: Color(hex: "#2953be")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#6a3fa0"),
            paletteWhite: Color(hex: "#e7e6fb"),
            accentColor: Color(hex: "#01a93c"),
            accentColor2: Color(hex: "#f64a8b"),
            backgroundColor: Color(hex: "#977bb7"),
            secondaryBackgroundColor: Color(hex: "#483d8c"),
            textColor: Color(hex: "#2a1f43"),
            moduleColor: Color(hex: "#604b8b")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#f1e331"),
            paletteWhite: Color(hex: "#ffdef4"),
            accentColor: Color(hex: "#0c6f69"),
            accentColor2: Color(hex: "#cb1f7b"),
            backgroundColor: Color(hex: "#efea97"),
            secondaryBackgroundColor: Color(hex: "#dd143f"),
            textColor: Color(hex: "#000000"),
            moduleColor: Color(hex: "#9e1d32")
        )
    ]
    
    // Dark Winter Themes
    static let darkWinterThemes: [SeasonTheme] = [
        SeasonTheme(
            primaryColor: Color(hex: "#679acd"),
            paletteWhite: Color(hex: "#c0c0c0"),
            accentColor: Color(hex: "#018380"),
            accentColor2: Color(hex: "#df5286"),
            backgroundColor: Color(hex: "#c1c2cb"),
            secondaryBackgroundColor: Color(hex: "#0e4e93"),
            textColor: Color(hex: "#3b2e39"),
            moduleColor: Color(hex: "#2d62a4")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#966ba2"),
            paletteWhite: Color(hex: "#bbb9d5"),
            accentColor: Color(hex: "#01694f"),
            accentColor2: Color(hex: "#c61d3a"),
            backgroundColor: Color(hex: "#999999"),
            secondaryBackgroundColor: Color(hex: "#8e4484"),
            textColor: Color(hex: "#2c262d"),
            moduleColor: Color(hex: "#893262")
        ),
        SeasonTheme(
            primaryColor: Color(hex: "#d4af41"),
            paletteWhite: Color(hex: "#f7cac9"),
            accentColor: Color(hex: "#01585f"),
            accentColor2: Color(hex: "#9c1c31"),
            backgroundColor: Color(hex: "#f0e79f"),
            secondaryBackgroundColor: Color(hex: "#9b6616"),
            textColor: Color(hex: "#0a0a0a"),
            moduleColor: Color(hex: "#8c0304")
        )
    ]
}
