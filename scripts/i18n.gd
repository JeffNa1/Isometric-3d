class_name I18n
extends RefCounted

## Centralized Localization System (Tiếng Việt & English)
## Provides reactive translation retrieval, locale switching and signals.

static var current_language: String = "vi"

static var _strings: Dictionary = {
	"vi": {
		# Common
		"btn_confirm": "XÁC NHẬN",
		"btn_close": "ĐÓNG",
		"btn_back": "QUAY LẠI",
		
		# Main Menu
		"menu_subtitle": " CYBER APOCALYPSE • KHẢI HUYỀN BẦY QUÁI ",
		"menu_footer": "v1.5.0 • BẢN THƯƠNG MẠI • 60 FPS • CÔNG NGHỆ MULTIMESH",
		"btn_play_title": "CHIẾN DỊCH MỚI",
		"btn_play_desc": "Bắt đầu cuộc chiến sinh tồn vô tận",
		"btn_sandbox_title": "PHÒNG THÍ NGHIỆM",
		"btn_sandbox_desc": "Thử nghiệm tự do: spawn quái, dummy, max nâng cấp & đo DPS",
		"btn_operatives_title": "CHỌN CHIẾN BINH",
		"btn_operatives_desc": "4 Đặc nhiệm: Vex, Pyro, Volt, Colossus",
		"btn_armory_title": "KHO CÔNG NGHỆ CYBER",
		"btn_armory_desc": "Nâng cấp vĩnh viễn 11 chỉ số tác chiến",
		"btn_how_to_play_title": "CẨM NANG SINH TỒN",
		"btn_how_to_play_desc": "Hệ thống vũ khí, tiến hóa & di chuyển",
		"btn_settings_title": "THIẾT LẬP HỆ THỐNG",
		"btn_settings_desc": "Âm lượng, rung chấn & số sát thương",
		"btn_credits_title": "DANH THẦN & ĐỘI NGŨ",
		"btn_credits_desc": "Bản quyền & đội ngũ phát triển game",
		"btn_quit_title": "THOÁT TRÒ CHƠI",
		"btn_quit_desc": "Lưu trạng thái & trở về desktop",

		# Stats Panel
		"stats_header": "💎 HỒ SƠ TÁC CHIẾN TỔNG HỢP",
		"stats_nanites": "NANITE CORES: %d 💎",
		"stats_record": "KỶ LỤC SINH TỒN: %02d:%02d",
		"stats_kills": "TỔNG TIÊU DIỆT: %d QUÁI",
		"stats_op": "CHIẾN BINH: %s",

		# Settings Modal
		"settings_title": "⚙ THIẾT LẬP HỆ THỐNG",
		"settings_volume": "Âm Lượng Tổng:",
		"settings_shake": "Độ Rung (Screen Shake):",
		"settings_dmg_num": "Hiện Số Sát Thương:",
		"settings_dmg_on": " [ BẬT ] ",
		"settings_dmg_off": " [ TẮT ] ",
		"settings_lang": "Ngôn Ngữ (Language):",
		"settings_lang_btn": " [ TIẾNG VIỆT ] ",
		"settings_back": "◀ ĐÓNG THIẾT LẬP",

		# How To Play Modal
		"how_title": "📖 CẨM NANG CHIẾN THUẬT",
		"how_back": "◀ QUAY LẠI MENU",
		"how_wasd_title": "ĐIỀU KHIỂN",
		"how_wasd_desc": "Cụm phím W-A-S-D hoặc Mũi Tên di chuyển luồn lách né quái 360°.",
		"how_combat_title": "TÁC CHIẾN",
		"how_combat_desc": "7 Vũ khí tự động khóa mục tiêu và xả hỏa lực liên hoàn.",
		"how_drops_title": "BẢO BỐI",
		"how_drops_desc": "65 Hòm tiếp tế: Bom EMP xóa sạch sàn, Hút Ngọc, Siêu Máu, Quá Tải x2.",
		"how_evo_title": "TIẾN HÓA",
		"how_evo_desc": "Vũ Khí Cấp 5 + Bị Động = Siêu Vũ Khí! Diệt Trùm 05:00 bú Rương Jackpot.",

		# Operatives Modal
		"op_modal_title": "⚡ CHỌN ĐẶC NHIỆM TÁC CHIẾN",
		"op_confirm": "XÁC NHẬN CHIẾN BINH",
		"op_selected": "★ ĐANG CHỌN ★",
		"op_back": "◀ QUAY LẠI MENU",
		"op_locked": "CHƯA MỞ KHÓA",
		"op_unlock_req": "Cần %d kills để mở khóa",

		# Operative Definitions
		"op_vex_name": "VEX - PHÁ THIÊN",
		"op_vex_title": "BÓNG MA ĐỘT KÍCH",
		"op_vex_desc": "+15% Tốc chạy, +10% Chí mạng, +5% Sát thương. Chuyên gia luồn lách và tỉa laser kép.",
		"op_pyro_name": "PYRO - HỎA TRẬN",
		"op_pyro_title": "BẬC THẦY HỎA NGỤC",
		"op_pyro_desc": "+25% Phạm vi nổ/lửa, +15% HP. Thiêu đốt quét sạch mọi quái vật áp sát.",
		"op_volt_name": "VOLT - LÔI TỘC",
		"op_volt_title": "THỢ SĂN SẤM SÉT",
		"op_volt_desc": "-15% Hồi chiêu, +20% Phạm vi hút ngọc. Xả điện liên hoàn giật nát bầy đàn.",
		"op_colossus_name": "COLOSSUS - KIM CƯƠNG",
		"op_colossus_title": "PHÁO ĐÀI BỌC THÉP",
		"op_colossus_desc": "+4 Giáp sắt cản đòn, +50 HP tối đa, -10% Tốc chạy. Thiết giáp bất tử cận chiến.",

		# Armory Modal
		"armory_title": "🛠 KHO CÔNG NGHỆ CYBER (NÂNG CẤP VĨNH VIỄN)",
		"armory_refund": "🔄 TẨY ĐIỂM HOÀN TRẢ 100% NANITES",
		"armory_back": "◀ QUAY LẠI MENU",
		"armory_buy": "NÂNG CẤP (%d 💎)",
		"armory_max": "★ ĐÃ TỐI ĐA ★",
		"armory_cost": "Giá: %d Nanites",

		# Upgrades Definitions
		"up_max_health_name": "LÕI SINH LỰC",
		"up_max_health_desc": "+10 Máu tối đa mỗi cấp",
		"up_max_health_unit": "+10 HP",
		"up_armor_name": "GIÁP COMPOSITE",
		"up_armor_desc": "-1 Sát thương nhận vào mỗi đòn",
		"up_armor_unit": "+1 Giáp",
		"up_regen_name": "NANO TỰ HỒI",
		"up_regen_desc": "+0.5 Máu hồi mỗi giây",
		"up_regen_unit": "+0.5 HP/s",
		"up_move_speed_name": "ĐỘNG CƠ PHẢN LỰC",
		"up_move_speed_desc": "+5% Tốc độ di chuyển",
		"up_move_speed_unit": "+5% Tốc độ",
		"up_magnet_name": "TRƯỜNG TỪ TÍNH",
		"up_magnet_desc": "+15% Phạm vi hút ngọc kinh nghiệm",
		"up_magnet_unit": "+15% Tầm hút",
		"up_damage_name": "CHÍP XUNG KÍCH",
		"up_damage_desc": "+3% Tổng sát thương mọi vũ khí",
		"up_damage_unit": "+3% Sát thương",
		"up_cooldown_name": "BỘ LÀM MÁT LỎNG",
		"up_cooldown_desc": "-2.5% Hồi chiêu mọi vũ khí",
		"up_cooldown_unit": "-2.5% Hồi chiêu",
		"up_crit_name": "LĂNG KÍNH CHÍ MẠNG",
		"up_crit_desc": "+3% Tỉ lệ chí mạng (x2.0 dmg)",
		"up_crit_unit": "+3% Chí mạng",
		"up_rerolls_name": "ĐIỀU HƯỚNG TẬP LỆNH",
		"up_rerolls_desc": "+1 Lượt đổi thẻ khi lên cấp",
		"up_rerolls_unit": "+1 Lượt đổi",
		"up_banishes_name": "GIAO THỨC TẨY TRỪ",
		"up_banishes_desc": "+1 Lượt loại bỏ thẻ vĩnh viễn trong run",
		"up_banishes_unit": "+1 Lượt bỏ",
		"up_nanite_gain_name": "BỘ THU NANITE",
		"up_nanite_gain_desc": "+10% Nanites thu thập mỗi trận",
		"up_nanite_gain_unit": "+10% Nanite",

		# Credits Modal
		"credits_title": "🎖️ DANH THẦN & ĐỘI NGŨ PHÁT TRIỂN",
		"credits_back": "◀ ĐÓNG BẢNG DANH THẦN",

		# HUD & Level Up
		"hud_swarm_stable": "BẦY QUÁI: %d [ỔN ĐỊNH]",
		"hud_swarm_warning": "BẦY QUÁI: %d [CẢNH BÁO]",
		"hud_swarm_critical": "BẦY QUÁI: %d [NGUY CẤP!]",
		"hud_tactical_reroll": "🎲 ĐỔI THẺ (Còn %d)",
		"hud_tactical_banish": "🚫 TẨY TRỪ (Còn %d)",
		"hud_tactical_back": "◀ QUAY LẠI CHỌN",
		"hud_tactical_skip": "⏩ BỎ QUA (+50 NANITES)",

		"hud_card_banish_mode": "🚫 CHỌN ĐỂ LOẠI BỎ KHỎI RUN",
		"hud_card_evo_tag": "👑 TIẾN HÓA TỐI THƯỢNG",
		"hud_card_passive_tag": "💠 NỘI TẠI CÔNG NGHỆ",
		"hud_card_new_tag": "✨ VŨ KHÍ MỚI",
		"hud_card_upgrade_tag": "⚡ CƯỜNG HÓA VŨ KHÍ",

		"hud_card_btn_banish": "🚫 XÓA VĨNH VIỄN KHỎI RUN",
		"hud_card_btn_evo": "👑 TIẾN HÓA NGAY ▶",
		"hud_card_btn_upgrade": "⚡ BÚ NÂNG CẤP NÀY ▶",

		"hud_meter_evo": "👑 TIẾN HÓA TỐI THƯỢNG - MAX LEVEL",
		"hud_meter_lvl": "CẤP %d/5  [%s]",

		# Weapons In Game
		"wpn_railgun_title_new": "⚡ SÚNG LASER RAILGUN",
		"wpn_railgun_desc_new": "Mở khóa chùm laser cao tần xuyên thủng hàng loạt quái vật theo đường thẳng.",
		"wpn_railgun_bonus_new": "MỞ KHÓA VŨ KHÍ MỚI",
		"wpn_railgun_title_up": "⚡ CƯỜNG HÓA RAILGUN",
		"wpn_railgun_desc_up": "Tăng độ rộng chùm laser, độ dài và sát thương xuyên thấu.",
		"wpn_railgun_bonus_up": "+30% SÁT THƯƠNG & TIA RỘNG",

		"wpn_flame_title_new": "🔥 SÚNG PHUN LỬA",
		"wpn_flame_desc_new": "Mở khóa luồng lửa plasma thiêu đốt quái vật phía trước mặt.",
		"wpn_flame_bonus_new": "MỞ KHÓA VŨ KHÍ MỚI",
		"wpn_flame_title_up": "🔥 NÂNG CẤP LỬA PLASMA",
		"wpn_flame_desc_up": "Mở rộng góc phun, tăng tầm xa và sát thương thiêu đốt.",
		"wpn_flame_bonus_up": "+25% GÓC & TẦM PHUN",

		"wpn_shockwave_title_new": "💥 SÓNG CHẤN ĐỘNG NOVA",
		"wpn_shockwave_desc_new": "Mở khóa vòng sóng xung kích hất tung toàn bộ quái vật áp sát.",
		"wpn_shockwave_bonus_new": "MỞ KHÓA VŨ KHÍ MỚI",
		"wpn_shockwave_title_up": "💥 NÂNG CẤP SHOCKWAVE",
		"wpn_shockwave_desc_up": "Tăng bán kính nổ, lực đẩy lùi và giảm thời gian nạp chiêu.",
		"wpn_shockwave_bonus_up": "+35% BÁN KÍNH SÓNG NỔ",

		"wpn_missile_title_new": "🚀 TÊN LỬA TỰ DẪN",
		"wpn_missile_desc_new": "Mở khóa bệ phóng tên lửa tầm nhiệt bắn đạn chùm nổ diện rộng.",
		"wpn_missile_bonus_new": "MỞ KHÓA VŨ KHÍ MỚI",
		"wpn_missile_title_up": "🚀 NÂNG CẤP TÊN LỬA",
		"wpn_missile_desc_up": "Bắn thêm tên lửa mỗi loạt, tăng bán kính nổ và giảm hồi chiêu.",
		"wpn_missile_bonus_up": "+2 TÊN LỬA TẦM NHIỆT / LOẠT",

		"wpn_blade_title_new": "🌀 LƯỠI HÁI QUỸ ĐẠO",
		"wpn_blade_desc_new": "Mở khóa lưỡi dao năng lượng xoay quanh người bảo vệ cận chiến.",
		"wpn_blade_bonus_new": "MỞ KHÓA VŨ KHÍ MỚI",
		"wpn_blade_title_up": "🌀 NÂNG CẤP LƯỠI HÁI",
		"wpn_blade_desc_up": "Tăng số lượng lưỡi dao, tốc độ xoay và bán kính quỹ đạo.",
		"wpn_blade_bonus_up": "+1 LƯỠI HÁI QUỸ ĐẠO",

		"wpn_tesla_title_new": "⚡ CUỘN DÂY TESLA",
		"wpn_tesla_desc_new": "Mở khóa phóng tia điện giật lan truyền qua nhiều kẻ địch liên tiếp.",
		"wpn_tesla_bonus_new": "MỞ KHÓA VŨ KHÍ MỚI",
		"wpn_tesla_title_up": "⚡ NÂNG CẤP TESLA",
		"wpn_tesla_desc_up": "Tăng số lần giật lan, sát thương điện và giảm thời gian nạp.",
		"wpn_tesla_bonus_up": "+2 TIA SÉT LAN TRUYỀN",

		"wpn_mortar_title_new": "☣️ PHÁO CỐI AXÍT",
		"wpn_mortar_desc_new": "Mở khóa bắn đạn axít vòng cung tạo vũng độc ăn mòn diện rộng.",
		"wpn_mortar_bonus_new": "MỞ KHÓA VŨ KHÍ MỚI",
		"wpn_mortar_title_up": "☣️ NÂNG CẤP PHÁO CỐI",
		"wpn_mortar_desc_up": "Bắn thêm đạn cối, tăng bán kính và sát thương vũng axít.",
		"wpn_mortar_bonus_up": "+1 ĐẠN PHÁO CỐI AXÍT",

		# Super Evolutions
		"evo_railgun_title": "⚡ HYPERION TACHYON",
		"evo_railgun_desc": "Bắn chùm laser kép hủy diệt liên tục xé toạc toàn bộ chiến trường!",
		"evo_railgun_bonus": "MAX TIẾN HÓA • LASER KÉP",

		"evo_flame_title": "🔥 INFERNAL SUNSTORM",
		"evo_flame_desc": "Phun bão lửa plasma xoay tròn 360° thiêu rụi mọi quái vật áp sát!",
		"evo_flame_bonus": "MAX TIẾN HÓA • BÃO LỬA 360°",

		"evo_shockwave_title": "💥 SUPERNOVA ZERO",
		"evo_shockwave_desc": "Sóng nổ kép hố đen nén quái lại rồi kích nổ kinh thiên động địa!",
		"evo_shockwave_bonus": "MAX TIẾN HÓA • HỐ ĐEN KÉP",

		"evo_missile_title": "🚀 APOCALYPSE BARRAGE",
		"evo_missile_desc": "Phóng loạt 6 tên lửa đạn chùm tầm nhiệt nổ liên hoàn khắp màn hình!",
		"evo_missile_bonus": "MAX TIẾN HÓA • 6 TÊN LỬA TẦM NHIỆT",

		"evo_blade_title": "🌀 OMNI-SCYTHE VORTEX",
		"evo_blade_desc": "6 lưỡi hái năng lượng khổng lồ bọc kín không gian xung quanh!",
		"evo_blade_bonus": "MAX TIẾN HÓA • 6 LƯỠI HÁI OMNI",

		"evo_tesla_title": "⚡ MJOLNIR STORMCORE",
		"evo_tesla_desc": "Bão sấm sét cuồng nộ giáng liên hoàn khắp bản đồ xé nát quân thù!",
		"evo_tesla_bonus": "MAX TIẾN HÓA • SẤM SÉT TOÀN BẢN ĐỒ",

		"evo_mortar_title": "☣️ CORROSIVE CHERNOBYL",
		"evo_mortar_desc": "Bắn 3 pháo cối phóng xạ tạo biển axít hủy diệt làm tan chảy mọi quái vật!",
		"evo_mortar_bonus": "MAX TIẾN HÓA • 3 PHÁO CỐI BIỂN AXÍT",

		# Passives
		"pas_energy_core_title": "⚡ PIN NĂNG LƯỢNG",
		"pas_energy_core_desc": "Giảm 12% thời gian hồi chiêu mọi vũ khí (Tiến hóa Railgun & Tesla).",
		"pas_energy_core_bonus": "-12% HỒI CHIÊU TOÀN DIỆN",

		"pas_nano_armor_title": "🩸 GIÁP HỢP KIM",
		"pas_nano_armor_desc": "+30 Máu tối đa và hồi phục 1.5 HP/giây (Tiến hóa Lưỡi Hái).",
		"pas_nano_armor_bonus": "+30 HP & +1.5 HP/GIÂY",

		"pas_thrusters_title": "👟 BỘ ĐẨY PHẢN LỰC",
		"pas_thrusters_desc": "+35 Tốc độ di chuyển để luồn lách né quái (Tiến hóa Phun Lửa).",
		"pas_thrusters_bonus": "+35 TỐC ĐỘ DI CHUYỂN",

		"pas_magnet_title": "🧲 BỘ HÚT TINH THỂ",
		"pas_magnet_desc": "+65 Bán kính hút ngọc kinh nghiệm từ xa (Tiến hóa Tên Lửa).",
		"pas_magnet_bonus": "+65 BÁN KÍNH HÚT TINH THỂ",

		"pas_amp_title": "💥 CHÍP KHUẾCH ĐẠI",
		"pas_amp_desc": "+20% Sát thương toàn bộ kho vũ khí (Tiến hóa Shockwave & Pháo Cối).",
		"pas_amp_bonus": "+20% TỔNG SÁT THƯƠNG",

		# Game Over & Victory
		"game_over_win": "🏆 CHIẾN THẮNG HUY HOÀNG - TÁC CHIẾN HOÀN TẤT! 🏆",
		"game_over_loss": "☠️ TỬ TRẬN TRONG DANH DỰ • KẾT THÚC CHIẾN DỊCH ☠️",
		"game_over_stats": "CHIẾN BINH: %s\n⏱️ THỜI GIAN SINH TỒN: %02d:%02d%s    |    ⭐ CẤP ĐỘ ĐẠT ĐƯỢC: LVL %d\n💀 TIÊU DIỆT BẦY QUÁI: %d CON    |    💎 NANITES THU ĐƯỢC: +%d (TỔNG: %d)",
		"game_over_new_record": " 🔥 [KỶ LỤC MỚI!]",
		"game_over_debrief_header": "--- HIỆU SUẤT SÁT THƯƠNG KHO VŨ KHÍ ---",
		"game_over_no_dmg": "Chưa ghi nhận sát thương vũ khí.",
		"game_over_restart": "🔄 CHƠI LẠI",
		"game_over_menu": "🏠 MENU CHÍNH",

		# Pause Modal
		"pause_title": "⏸️ TẠM DỪNG TRẬN ĐẤU",
		"pause_resume": "▶️ TIẾP TỤC CHIẾN",
		"pause_restart": "🔄 CHƠI LẠI TỪ ĐẦU",
		"pause_menu": "🏠 VỀ MENU CHÍNH",
		"pause_lang": "🌐 NGÔN NGỮ: TIẾNG VIỆT",

		# Chest Modal
		"chest_title": "📦 RƯƠNG TIẾP TẾ CHIẾN THUẬT",
		"chest_claim": "💎 NHẬN TẤT CẢ PHẦN THƯỞNG 💎",

		# Field Pickups
		"pickup_emp": "💥 EMP TẬN DIỆT TOÀN BẢN ĐỒ!",
		"pickup_magnet": "🧲 LỰC HÚT TOÀN BỘ NGỌC!",
		"pickup_heal": "🩸 HỒI PHỤC SIÊU CẤP 100%!",
		"pickup_speed": "⚡ QUÁ TẢI TỐC ĐỘ 200%!",

		# Alerts (Main.gd)
		"alert_crate": "📦 THÙNG TIẾP TẾ CHIẾN THUẬT ĐÃ ĐÁP XUỐNG! 📦",
		"alert_spitters": "☣️ CẢNH BÁO: BỌ PHUN ĐỘC TẦM XA TIẾP CẬN! ☣️",
		"alert_exploders": "⚠️ NGUY CẤP: BẦY BỌ TỰ NỔ CẢM TỬ LAO TỚI! ⚠️",
		"alert_win_15": "👑 CHIẾN THẮNG 10 PHÚT! KÍCH HOẠT CHẾ ĐỘ VÔ TẬN! 👑",
		"alert_enrage": "🔥 CUỒNG NỘ VÔ TẬN CẤP %d: QUÁI TĂNG TỐC & SÁT THƯƠNG! 🔥",
		"alert_leviathan": "💀 BÁ CHỦ VỰC THẲM: APEX LEVIATHAN ĐÃ XUẤT HIỆN! 💀",
		"alert_dreadnought": "⚡ CHIẾN HẠM TITAN: CYBER DREADNOUGHT TIẾP CẬN! ⚡",
		"alert_swarm": "⚠️ CẢNH BÁO: ĐỢT SÓNG QUÁI VÂY HÃM! ⚠️",
		"alert_elite": "👑 CẢNH BÁO: QUÁI TINH ANH KHỔNG LỒ TIẾP CẬN! 👑",
		"alert_behemoth": "⚠️ CỰ THÚ VOLCANIC BEHEMOTH TIẾP CẬN! ⚠️",
		"streak_godlike": "👑 %d DIỆT VỰC THẲM THẦN THÁNH! 👑",
		"streak_unstoppable": "💥 %d HỦY DIỆT KHÔNG THỂ CẢN! 💥",
		"streak_50": "⚡ %d COMBO LIÊN HOÀN! ⚡",
		"streak_100": "🔥 %d SIÊU SÁT THỦ! 🔥",
		"streak_250": "💥 %d CUỒNG NỘ QUÉT SẠCH! 💥",
		"streak_500": "💀 %d BẤT KHẢ CHIẾN BẠI! 💀",
		"streak_1000": "👑 %d HUYỀN THOẠI DIỆT THẾ! 👑",
		"streak_2000": "⚡ %d ĐẠI HỌA TẬN DIỆT! ⚡",
		"streak_3000": "🌌 %d TRANSCENDENCE VÔ CỰC! 🌌"
	},

	"en": {
		# Common
		"btn_confirm": "CONFIRM",
		"btn_close": "CLOSE",
		"btn_back": "BACK",

		# Main Menu
		"menu_subtitle": " CYBER APOCALYPSE • SWARM ARMAGEDDON ",
		"menu_footer": "v1.5.0 • COMMERCIAL EDITION • 60 FPS CAP • MULTIMESH TECH",
		"btn_play_title": "NEW CAMPAIGN",
		"btn_play_desc": "Embark on endless cybernetic survival warfare",
		"btn_sandbox_title": "SANDBOX LAB",
		"btn_sandbox_desc": "Free testing: spawn entities, dummy, max upgrades & DPS meter",
		"btn_operatives_title": "SELECT OPERATIVE",
		"btn_operatives_desc": "4 Operatives: Vex, Pyro, Volt, Colossus",
		"btn_armory_title": "CYBER ARMORY",
		"btn_armory_desc": "Permanently upgrade 11 tactical combat stats",
		"btn_how_to_play_title": "SURVIVAL GUIDE",
		"btn_how_to_play_desc": "Weapon systems, evolutions & controls",
		"btn_settings_title": "SYSTEM SETTINGS",
		"btn_settings_desc": "Volume, screen shake & damage numbers",
		"btn_credits_title": "CREDITS & TEAM",
		"btn_credits_desc": "License & game development team",
		"btn_quit_title": "QUIT GAME",
		"btn_quit_desc": "Save progress & return to desktop",

		# Stats Panel
		"stats_header": "💎 MISSION PROFILE SUMMARY",
		"stats_nanites": "NANITE CORES: %d 💎",
		"stats_record": "SURVIVAL RECORD: %02d:%02d",
		"stats_kills": "TOTAL KILLS: %d BUGS",
		"stats_op": "OPERATIVE: %s",

		# Settings Modal
		"settings_title": "⚙ SYSTEM SETTINGS",
		"settings_volume": "Master Volume:",
		"settings_shake": "Screen Shake:",
		"settings_dmg_num": "Damage Numbers:",
		"settings_dmg_on": " [ ON ] ",
		"settings_dmg_off": " [ OFF ] ",
		"settings_lang": "Language (Ngôn Ngữ):",
		"settings_lang_btn": " [ ENGLISH ] ",
		"settings_back": "◀ CLOSE SETTINGS",

		# How To Play Modal
		"how_title": "📖 TACTICAL SURVIVAL GUIDE",
		"how_back": "◀ BACK TO MENU",
		"how_wasd_title": "CONTROLS",
		"how_wasd_desc": "W-A-S-D or Arrow Keys for 360° fluid omnidirectional movement.",
		"how_combat_title": "COMBAT",
		"how_combat_desc": "7 Weapons auto-lock closest threats and unleash continuous firepower.",
		"how_drops_title": "FIELD DROPS",
		"how_drops_desc": "Supply crates: EMP Bomb screen clear, Gem Magnet, Super Heal, 2x Speed Overload.",
		"how_evo_title": "EVOLUTIONS",
		"how_evo_desc": "Level 5 Weapon + Passive = Super Evolution! Slay Bosses for Jackpot Chests.",

		# Operatives Modal
		"op_modal_title": "⚡ SELECT COMBAT OPERATIVE",
		"op_confirm": "CONFIRM OPERATIVE",
		"op_selected": "★ SELECTED ★",
		"op_back": "◀ BACK TO MENU",
		"op_locked": "LOCKED",
		"op_unlock_req": "Requires %d kills to unlock",

		# Operative Definitions
		"op_vex_name": "VEX - SKYBREAKER",
		"op_vex_title": "STRIKE SPECTRE",
		"op_vex_desc": "+15% Move Speed, +10% Crit Rate, +5% Damage. Nimble scout specialized in dual laser fire.",
		"op_pyro_name": "PYRO - FIRESTORM",
		"op_pyro_title": "INFERNAL MASTER",
		"op_pyro_desc": "+25% Blast/Flame Radius, +15% HP. Incinerates hordes with wide-area plasma waves.",
		"op_volt_name": "VOLT - THUNDERBORN",
		"op_volt_title": "LIGHTNING HUNTER",
		"op_volt_desc": "-15% Cooldown, +20% Magnet Radius. Discharges cascading chain lightning arcs.",
		"op_colossus_name": "COLOSSUS - TITANIUM",
		"op_colossus_title": "ARMORED JUGGERNAUT",
		"op_colossus_desc": "+4 Armor reduction, +50 Max HP, -10% Move Speed. Unstoppable frontline fortress.",

		# Armory Modal
		"armory_title": "🛠 CYBER ARMORY (PERMANENT UPGRADES)",
		"armory_refund": "🔄 REFUND ALL 100% NANITES",
		"armory_back": "◀ BACK TO MENU",
		"armory_buy": "UPGRADE (%d 💎)",
		"armory_max": "★ MAX LEVEL ★",
		"armory_cost": "Cost: %d Nanites",

		# Upgrades Definitions
		"up_max_health_name": "VITAL CORE",
		"up_max_health_desc": "+10 Max Health per level",
		"up_max_health_unit": "+10 HP",
		"up_armor_name": "COMPOSITE ARMOR",
		"up_armor_desc": "-1 Incoming damage per hit",
		"up_armor_unit": "+1 Armor",
		"up_regen_name": "NANO REPAIR",
		"up_regen_desc": "+0.5 Health regeneration per second",
		"up_regen_unit": "+0.5 HP/s",
		"up_move_speed_name": "THRUST ENGINE",
		"up_move_speed_desc": "+5% Movement Speed",
		"up_move_speed_unit": "+5% Speed",
		"up_magnet_name": "MAGNETIC FIELD",
		"up_magnet_desc": "+15% XP Gem pickup radius",
		"up_magnet_unit": "+15% Magnet",
		"up_damage_name": "OVERCHARGE CHIP",
		"up_damage_desc": "+3% Overall damage for all weapons",
		"up_damage_unit": "+3% Damage",
		"up_cooldown_name": "LIQUID COOLANT",
		"up_cooldown_desc": "-2.5% Cooldown for all weapons",
		"up_cooldown_unit": "-2.5% Cooldown",
		"up_crit_name": "CRITICAL PRISM",
		"up_crit_desc": "+3% Critical Strike Chance (x2.0 dmg)",
		"up_crit_unit": "+3% Crit",
		"up_rerolls_name": "TACTICAL REROLL",
		"up_rerolls_desc": "+1 Card Reroll charge per level up",
		"up_rerolls_unit": "+1 Reroll",
		"up_banishes_name": "PURGE PROTOCOL",
		"up_banishes_desc": "+1 Card Banish charge per run",
		"up_banishes_unit": "+1 Banish",
		"up_nanite_gain_name": "NANITE COLLECTOR",
		"up_nanite_gain_desc": "+10% Nanites gained per battle",
		"up_nanite_gain_unit": "+10% Nanite",

		# Credits Modal
		"credits_title": "🎖️ CREDITS & DEVELOPMENT TEAM",
		"credits_back": "◀ CLOSE CREDITS",

		# HUD & Level Up
		"hud_swarm_stable": "SWARM: %d [STABLE]",
		"hud_swarm_warning": "SWARM: %d [WARNING]",
		"hud_swarm_critical": "SWARM: %d [CRITICAL!]",
		"hud_tactical_reroll": "🎲 REROLL (%d Left)",
		"hud_tactical_banish": "🚫 BANISH (%d Left)",
		"hud_tactical_back": "◀ BACK TO SELECT",
		"hud_tactical_skip": "⏩ SKIP (+50 NANITES)",

		"hud_card_banish_mode": "🚫 SELECT TO BANISH FROM RUN",
		"hud_card_evo_tag": "👑 SUPER EVOLUTION",
		"hud_card_passive_tag": "💠 TECH PASSIVE",
		"hud_card_new_tag": "✨ NEW WEAPON",
		"hud_card_upgrade_tag": "⚡ WEAPON UPGRADE",

		"hud_card_btn_banish": "🚫 PERMANENTLY BANISH",
		"hud_card_btn_evo": "👑 EVOLVE NOW ▶",
		"hud_card_btn_upgrade": "⚡ SELECT UPGRADE ▶",

		"hud_meter_evo": "👑 SUPER EVOLUTION - MAX LEVEL",
		"hud_meter_lvl": "LVL %d/5  [%s]",

		# Weapons In Game
		"wpn_railgun_title_new": "⚡ RAILGUN LASER",
		"wpn_railgun_desc_new": "Unlock high-frequency piercing laser cutting through entire enemy lines.",
		"wpn_railgun_bonus_new": "NEW WEAPON UNLOCKED",
		"wpn_railgun_title_up": "⚡ UPGRADE RAILGUN",
		"wpn_railgun_desc_up": "Increase laser beam width, length, and piercing damage.",
		"wpn_railgun_bonus_up": "+30% DAMAGE & BEAM WIDTH",

		"wpn_flame_title_new": "🔥 FLAMETHROWER",
		"wpn_flame_desc_new": "Unlock plasma fire stream incinerating forward swarms.",
		"wpn_flame_bonus_new": "NEW WEAPON UNLOCKED",
		"wpn_flame_title_up": "🔥 UPGRADE PLASMA FLAME",
		"wpn_flame_desc_up": "Expand spray angle, increase range and burning burn damage.",
		"wpn_flame_bonus_up": "+25% ANGLE & FLAME RANGE",

		"wpn_shockwave_title_new": "💥 NOVA SHOCKWAVE",
		"wpn_shockwave_desc_new": "Unlock seismic pulse knocking back and crushing surrounding hordes.",
		"wpn_shockwave_bonus_new": "NEW WEAPON UNLOCKED",
		"wpn_shockwave_title_up": "💥 UPGRADE SHOCKWAVE",
		"wpn_shockwave_desc_up": "Increase blast radius, knockback force, and reduce recharge time.",
		"wpn_shockwave_bonus_up": "+35% BLAST RADIUS",

		"wpn_missile_title_new": "🚀 HOMING MISSILES",
		"wpn_missile_desc_new": "Unlock heat-seeking cluster rockets with wide blast radius.",
		"wpn_missile_bonus_new": "NEW WEAPON UNLOCKED",
		"wpn_missile_title_up": "🚀 UPGRADE MISSILES",
		"wpn_missile_desc_up": "Fire additional missiles per salvo, increase blast radius and fire rate.",
		"wpn_missile_bonus_up": "+2 HOMING MISSILES / SALVO",

		"wpn_blade_title_new": "🌀 ORBITING SCYTHES",
		"wpn_blade_desc_new": "Unlock spinning plasma blades creating an impenetrable perimeter.",
		"wpn_blade_bonus_new": "NEW WEAPON UNLOCKED",
		"wpn_blade_title_up": "🌀 UPGRADE SCYTHES",
		"wpn_blade_desc_up": "Increase blade count, rotational speed, and orbital radius.",
		"wpn_blade_bonus_up": "+1 ORBITING SCYTHE",

		"wpn_tesla_title_new": "⚡ TESLA COIL",
		"wpn_tesla_desc_new": "Unlock high-voltage lightning discharging between consecutive targets.",
		"wpn_tesla_bonus_new": "NEW WEAPON UNLOCKED",
		"wpn_tesla_title_up": "⚡ UPGRADE TESLA",
		"wpn_tesla_desc_up": "Increase chain bounce count, electric damage, and charge rate.",
		"wpn_tesla_bonus_up": "+2 CHAIN LIGHTNING ARCS",

		"wpn_mortar_title_new": "☣️ ACID MORTAR",
		"wpn_mortar_desc_new": "Unlock lobbed corrosive shells spawning wide lingering acid pools.",
		"wpn_mortar_bonus_new": "NEW WEAPON UNLOCKED",
		"wpn_mortar_title_up": "☣️ UPGRADE MORTAR",
		"wpn_mortar_desc_up": "Fire extra mortar shells, increase puddle radius and melting damage.",
		"wpn_mortar_bonus_up": "+1 ACID MORTAR SHELL",

		# Super Evolutions
		"evo_railgun_title": "⚡ HYPERION TACHYON",
		"evo_railgun_desc": "Fires continuous devastating dual lasers tearing through the entire battlefield!",
		"evo_railgun_bonus": "MAX EVOLUTION • DUAL LASER",

		"evo_flame_title": "🔥 INFERNAL SUNSTORM",
		"evo_flame_desc": "Spews a 360° swirling plasma tempest vaporizing all adjacent swarm threats!",
		"evo_flame_bonus": "MAX EVOLUTION • 360° FIRESTORM",

		"evo_shockwave_title": "💥 SUPERNOVA ZERO",
		"evo_shockwave_desc": "Dual black hole pulses compress surrounding hordes then trigger a cataclysmic detonation!",
		"evo_shockwave_bonus": "MAX EVOLUTION • DUAL VORTEX",

		"evo_missile_title": "🚀 APOCALYPSE BARRAGE",
		"evo_missile_desc": "Launches a 6-rocket cluster barrage causing screen-wide chain explosions!",
		"evo_missile_bonus": "MAX EVOLUTION • 6 CLUSTER ROCKETS",

		"evo_blade_title": "🌀 OMNI-SCYTHE VORTEX",
		"evo_blade_desc": "6 colossal energy scythes create an impenetrable defensive whirlwind!",
		"evo_blade_bonus": "MAX EVOLUTION • 6 OMNI-SCYTHES",

		"evo_tesla_title": "⚡ MJOLNIR STORMCORE",
		"evo_tesla_desc": "Raining devastating thunderbolts map-wide to shatter all opposing forces!",
		"evo_tesla_bonus": "MAX EVOLUTION • MAP-WIDE THUNDER",

		"evo_mortar_title": "☣️ CORROSIVE CHERNOBYL",
		"evo_mortar_desc": "Launches 3 radioactive artillery shells creating a lethal sea of caustic acid!",
		"evo_mortar_bonus": "MAX EVOLUTION • 3 ACID POOLS",

		# Passives
		"pas_energy_core_title": "⚡ ENERGY CORE",
		"pas_energy_core_desc": "Reduces weapon cooldowns by 12% (Evolves Railgun & Tesla).",
		"pas_energy_core_bonus": "-12% ALL COOLDOWNS",

		"pas_nano_armor_title": "🩸 NANO COMPOSITE",
		"pas_nano_armor_desc": "+30 Max Health and regenerates 1.5 HP/sec (Evolves Scythes).",
		"pas_nano_armor_bonus": "+30 HP & +1.5 HP/SEC",

		"pas_thrusters_title": "👟 JET THRUSTERS",
		"pas_thrusters_desc": "+35 Movement Speed for superior evasion (Evolves Flamethrower).",
		"pas_thrusters_bonus": "+35 MOVEMENT SPEED",

		"pas_magnet_title": "🧲 CRYSTAL MAGNET",
		"pas_magnet_desc": "+65 XP Gem collection radius (Evolves Missiles).",
		"pas_magnet_bonus": "+65 PICKUP RADIUS",

		"pas_amp_title": "💥 AMPLIFIER CHIP",
		"pas_amp_desc": "+20% Total damage across entire arsenal (Evolves Shockwave & Mortar).",
		"pas_amp_bonus": "+20% TOTAL DAMAGE",

		# Game Over & Victory
		"game_over_win": "🏆 GLORIOUS VICTORY - MISSION ACCOMPLISHED! 🏆",
		"game_over_loss": "☠️ FALLEN WITH HONOR • OPERATION TERMINATED ☠️",
		"game_over_stats": "OPERATIVE: %s\n⏱️ SURVIVAL TIME: %02d:%02d%s    |    ⭐ LEVEL REACHED: LVL %d\n💀 SWARM SLAIN: %d BUGS    |    💎 NANITES GAINED: +%d (TOTAL: %d)",
		"game_over_new_record": " 🔥 [NEW RECORD!]",
		"game_over_debrief_header": "--- WEAPON ARSENAL DAMAGE BREAKDOWN ---",
		"game_over_no_dmg": "No weapon damage recorded.",
		"game_over_restart": "🔄 PLAY AGAIN",
		"game_over_menu": "🏠 MAIN MENU",

		# Pause Modal
		"pause_title": "⏸️ MISSION PAUSED",
		"pause_resume": "▶️ RESUME MISSION",
		"pause_restart": "🔄 RESTART MISSION",
		"pause_menu": "🏠 MAIN MENU",
		"pause_lang": "🌐 LANGUAGE: ENGLISH",

		# Chest Modal
		"chest_title": "📦 TACTICAL SUPPLY CHEST",
		"chest_claim": "💎 CLAIM ALL REWARDS 💎",

		# Field Pickups
		"pickup_emp": "💥 EMP MAP OBLITERATION!",
		"pickup_magnet": "🧲 GEM ATTRACTION SURGE!",
		"pickup_heal": "🩸 SUPER RECOVERY 100%!",
		"pickup_speed": "⚡ HYPERSPEED OVERLOAD 200%!",

		# Alerts (Main.gd)
		"alert_crate": "📦 TACTICAL SUPPLY CRATE DROPPED! 📦",
		"alert_spitters": "☣️ WARNING: ACID SPITTERS APPROACHING! ☣️",
		"alert_exploders": "⚠️ CRITICAL: SUICIDE EXPLODERS INCOMING! ⚠️",
		"alert_win_15": "👑 10-MINUTE VICTORY! ENDLESS MODE ACTIVATED! 👑",
		"alert_enrage": "🔥 ENDLESS ENRAGE LVL %d: SPEED & DAMAGE BOOSTED! 🔥",
		"alert_leviathan": "💀 ABYSS OVERLORD: APEX LEVIATHAN HAS AWAKENED! 💀",
		"alert_dreadnought": "⚡ TITAN WARSHIP: CYBER DREADNOUGHT APPROACHING! ⚡",
		"alert_swarm": "⚠️ WARNING: MASSIVE SWARM SURGE! ⚠️",
		"alert_elite": "👑 WARNING: GIANT ELITE CHAMPION APPROACHING! 👑",
		"alert_behemoth": "⚠️ VOLCANIC BEHEMOTH APPROACHING! ⚠️",
		"streak_godlike": "👑 %d GODLIKE ABYSS SLAYER! 👑",
		"streak_unstoppable": "💥 %d UNSTOPPABLE CARNAGE! 💥",
		"streak_50": "⚡ %d COMBO! ⚡",
		"streak_100": "🔥 %d ULTRA KILL! 🔥",
		"streak_250": "💥 %d RAMPAGE! 💥",
		"streak_500": "💀 %d UNSTOPPABLE! 💀",
		"streak_1000": "👑 %d GODLIKE MASSACRE! 👑",
		"streak_2000": "⚡ %d EXTINCTION EVENT! ⚡",
		"streak_3000": "🌌 %d APOCALYPSE TRANSCENDENCE! 🌌"
	}
}

static func loc(key: String, default_text: String = "") -> String:
	var lang_dict = _strings.get(current_language, _strings["vi"])
	if lang_dict.has(key):
		return lang_dict[key]
	var fallback_dict = _strings.get("vi", {})
	if fallback_dict.has(key):
		return fallback_dict[key]
	return default_text if default_text != "" else key

static func set_language(lang: String) -> void:
	if lang == "en" or lang == "vi":
		current_language = lang
	else:
		current_language = "vi"

static func get_language() -> String:
	return current_language

static func toggle_language() -> String:
	if current_language == "vi":
		set_language("en")
	else:
		set_language("vi")
	return current_language
