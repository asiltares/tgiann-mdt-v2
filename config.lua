Config = {}

Config.AllowedJobs = {
    ["lapd"] = true,
    ["lasd"] = true,
    ["cdcr"] = true,
    ["dea"] = true,
    ["hwpd"] = true,
    ["chp"] = true,
    ["police"] = true,
}

Config.MDTCommand = 'mdt'            -- MDT açma komutu adı
Config.MDTKey = 'F5'                 -- MDT açma tuşu

Config.ZoomCommand = 'tabletzoom'    -- Zoom ayarlama komutu
Config.ZoomKey = ''    

Config.Logs = {
    enabled = true,
    webhook = "https://discord.com/api/webhooks/1402106542467317880/s-00CLd4vlhLeDCYp8X26d4GMwSOAWDsroA5tsTkQoE7gTFdzMH4wXBz-qgYIdUbbgL-",
    olaylar = true,        -- olay ekle, sil vs.
    ceza = true,           -- ceza kaydı
    sorgula = true,        -- isim/numara/plaka/arac sorgulama
    sabika = true,         -- sabıka silme vs.
    aranan = true,         -- arama ekle/kaldır
    avatar = true,         -- avatar değişikliği
}
