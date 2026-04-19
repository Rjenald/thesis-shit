import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import '../constants/app_colors.dart';
import '../services/favorites_service.dart';
<<<<<<< HEAD
import '../services/spotify_service.dart';
=======
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
import '../widgets/bottom_nav_bar.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'education_mode_page.dart';
import 'karaoke_recording_page.dart';

// ── Song catalogue ────────────────────────────────────────────────────────────

const _allSongs = <Map<String, String>>[
  // ── BISAYA / CEBUANO (100) ────────────────────────────────────────────────
  // Traditional Cebuano Folk
  {'title':'Matud Nila','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/MatudNila/300/300','ytId':'Matud Nila Bisaya karaoke'},
  {'title':'Usahay','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/Usahay/300/300','ytId':'Usahay Bisaya folk karaoke'},
  {'title':'Dandansoy','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/Dandansoy/300/300','ytId':'Dandansoy Bisaya karaoke'},
  {'title':'Rosas Pandan','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/RosasPandan/300/300','ytId':'Rosas Pandan Bisaya karaoke'},
  {'title':'Handum','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/HandumCebuano/300/300','ytId':'Handum Bisaya karaoke'},
  {'title':'Buyog','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/BuyogCebuano/300/300','ytId':'Buyog Bisaya folk karaoke'},
  {'title':'Ako Si Kapitan','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/AkoSiKapitan/300/300','ytId':'Ako Si Kapitan Bisaya karaoke'},
  {'title':'Bitoon sa Langit','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/BitoonSaLangit/300/300','ytId':'Bitoon sa Langit Bisaya karaoke'},
  {'title':'Kasadya Ning Taknaa','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/KasadyaNingTaknaa/300/300','ytId':'Kasadya Ning Taknaa Bisaya karaoke'},
  {'title':'Pasko Na Sad Usab','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/PaskoNaSadUsab/300/300','ytId':'Pasko Na Sad Usab Bisaya karaoke'},
  {'title':'Sa Kabuntagon','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/SaKabuntagon/300/300','ytId':'Sa Kabuntagon Bisaya karaoke'},
  {'title':'Maayong Gabii','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/MaayongGabii/300/300','ytId':'Maayong Gabii Bisaya karaoke'},
  {'title':'Balud sa Dagat','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/BaludSaDagat/300/300','ytId':'Balud sa Dagat Bisaya karaoke'},
  {'title':'Babaye nga Bulak','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/BabayeNgaBulak/300/300','ytId':'Babaye nga Bulak Bisaya karaoke'},
  {'title':'Harana sa Kabuntagon','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/HaranaSaKabuntagon/300/300','ytId':'Harana sa Kabuntagon Bisaya karaoke'},
  {'title':'Mutya sa Sugbo','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/MutyaSaSugbo/300/300','ytId':'Mutya sa Sugbo Bisaya karaoke'},
  {'title':'Mag-ampo Ta','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/MagAmpoTa/300/300','ytId':'Mag-ampo Ta Bisaya karaoke'},
  {'title':'Duaw','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/DuawCebuano/300/300','ytId':'Duaw Bisaya folk karaoke'},
  {'title':'Ihatag Ko Nimo','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/IhataKoNimo/300/300','ytId':'Ihatag Ko Nimo Bisaya karaoke'},
  {'title':'Walay Sama','artist':'Traditional Cebuano','genre':'Bisaya','image':'https://picsum.photos/seed/WalaySama/300/300','ytId':'Walay Sama Bisaya karaoke'},
  // Yoyoy Villame
  {'title':'Pangga Ko Ikaw','artist':'Yoyoy Villame','genre':'Bisaya','image':'https://picsum.photos/seed/PanggaKoIkaw/300/300','ytId':'Pangga Ko Ikaw Yoyoy Villame karaoke'},
  {'title':'Beep Beep','artist':'Yoyoy Villame','genre':'Bisaya','image':'https://picsum.photos/seed/BeepBeepYoyoy/300/300','ytId':'Beep Beep Yoyoy Villame karaoke'},
  {'title':'Mr. Suave','artist':'Yoyoy Villame','genre':'Bisaya','image':'https://picsum.photos/seed/MrSuaveYoyoy/300/300','ytId':'Mr Suave Yoyoy Villame karaoke'},
  {'title':'Nosi Ba Lasi','artist':'Yoyoy Villame','genre':'Bisaya','image':'https://picsum.photos/seed/NosiBalasi/300/300','ytId':'Nosi Ba Lasi Yoyoy Villame karaoke'},
  {'title':'Mag-apas Tag Manok','artist':'Yoyoy Villame','genre':'Bisaya','image':'https://picsum.photos/seed/MagApasTagManok/300/300','ytId':'Mag-apas Tag Manok Yoyoy Villame karaoke'},
  // Bryan Termulo
  {'title':'Nindot Kaayo','artist':'Bryan Termulo','genre':'Bisaya','image':'https://picsum.photos/seed/NindotKaayo/300/300','ytId':'Nindot Kaayo Bryan Termulo karaoke'},
  {'title':'Langga','artist':'Bryan Termulo','genre':'Bisaya','image':'https://picsum.photos/seed/LanggaBryan/300/300','ytId':'Langga Bryan Termulo karaoke'},
  {'title':'Ikaw Ra Ang Akong Mahal','artist':'Bryan Termulo','genre':'Bisaya','image':'https://picsum.photos/seed/IkawRaAngAkong/300/300','ytId':'Ikaw Ra Ang Akong Mahal Bryan Termulo karaoke'},
  // GT Band
  {'title':'Imong Gugma','artist':'GT Band','genre':'Bisaya','image':'https://picsum.photos/seed/ImongGugmaGTBand/300/300','ytId':'Imong Gugma GT Band karaoke'},
  {'title':'Palaway','artist':'GT Band','genre':'Bisaya','image':'https://picsum.photos/seed/PalawayGTBand/300/300','ytId':'Palaway GT Band karaoke'},
  // Modern Bisaya
  {'title':'Palangga Ko Ikaw','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/PalanggaKoIkaw/300/300','ytId':'Palangga Ko Ikaw Bisaya karaoke'},
  {'title':'Usa Ka Gugma','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/UsakaGugma/300/300','ytId':'Usa Ka Gugma Bisaya karaoke'},
  {'title':'Ikaw Ra Gyud','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/IkawRaGyud/300/300','ytId':'Ikaw Ra Gyud Bisaya karaoke'},
  {'title':'Walay Lain Kundi Ikaw','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/WalayLainKundi/300/300','ytId':'Walay Lain Kundi Ikaw Bisaya karaoke'},
  {'title':'Gugma Ko','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/GugmaKoBisaya/300/300','ytId':'Gugma Ko Bisaya karaoke'},
  {'title':'Hinigugma Ko Ikaw','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/HinigugmaKoIkaw/300/300','ytId':'Hinigugma Ko Ikaw Bisaya karaoke'},
  {'title':'Bisan Pa Man','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/BisanPaMan/300/300','ytId':'Bisan Pa Man Bisaya karaoke'},
  {'title':'Unsa Ka Nimo','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/UnsaKaNimo/300/300','ytId':'Unsa Ka Nimo Bisaya karaoke'},
  {'title':'Naa Pa Bay Paglaum','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/NaaPaBayPagelaum/300/300','ytId':'Naa Pa Bay Paglaum Bisaya karaoke'},
  {'title':'Sa Akong Dughan','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/SaAkongDughan/300/300','ytId':'Sa Akong Dughan Bisaya karaoke'},
  {'title':'Kahinumdum Mo','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/KahinumdumMo/300/300','ytId':'Kahinumdum Mo Bisaya karaoke'},
  {'title':'Langit Ka Nako','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/LangitKaNako/300/300','ytId':'Langit Ka Nako Bisaya karaoke'},
  {'title':'Dili Ko Makalimot','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/DiliKoMakalimot/300/300','ytId':'Dili Ko Makalimot Bisaya karaoke'},
  {'title':'Unta','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/UntaBisaya/300/300','ytId':'Unta Bisaya karaoke'},
  {'title':'Pagmahal Ko Nimo','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/PagmahalKoNimo/300/300','ytId':'Pagmahal Ko Nimo Bisaya karaoke'},
  {'title':'Asa Man Ka','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/AsaManKa/300/300','ytId':'Asa Man Ka Bisaya karaoke'},
  {'title':'Amping Na Diha','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/AmpingNaDiha/300/300','ytId':'Amping Na Diha Bisaya karaoke'},
  {'title':'Atong Gugma','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/AtongGugma/300/300','ytId':'Atong Gugma Bisaya karaoke'},
  {'title':'Mahal Ta Ka','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/MahalTaKaBisaya/300/300','ytId':'Mahal Ta Ka Bisaya karaoke'},
  {'title':'Dili Nato Kaya','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/DiliNatoKaya/300/300','ytId':'Dili Nato Kaya Bisaya karaoke'},
  {'title':'Sulat Para Nimo','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/SulatParaNimo/300/300','ytId':'Sulat Para Nimo Bisaya karaoke'},
  {'title':'Layo Ka','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/LayoKaBisaya/300/300','ytId':'Layo Ka Bisaya karaoke'},
  {'title':'Balik Na','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/BalikNaBisaya/300/300','ytId':'Balik Na Bisaya karaoke'},
  {'title':'Paminaw','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/PaminawBisaya/300/300','ytId':'Paminaw Bisaya karaoke'},
  {'title':'Ang Akong Gugma','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/AngAkongGugma/300/300','ytId':'Ang Akong Gugma Bisaya karaoke'},
  {'title':'Pagbalik Mo','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/PagbalikMoBisaya/300/300','ytId':'Pagbalik Mo Bisaya karaoke'},
  {'title':'Salamat Nimo','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/SalamatNimo/300/300','ytId':'Salamat Nimo Bisaya karaoke'},
  {'title':'Ikaw Ang Tanan','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/IkawAngTanan/300/300','ytId':'Ikaw Ang Tanan Bisaya karaoke'},
  {'title':'Gusto Nako Nimo','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/GustoNakoNimo/300/300','ytId':'Gusto Nako Nimo Bisaya karaoke'},
  {'title':'Walay Kapuli','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/WalayKapuli/300/300','ytId':'Walay Kapuli Bisaya karaoke'},
  {'title':'Luha','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/LuhaBisaya/300/300','ytId':'Luha Bisaya karaoke'},
  {'title':'Pangandoy Ko','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/PangandoyKo/300/300','ytId':'Pangandoy Ko Bisaya karaoke'},
  {'title':'Dughan Ko','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/DughanKo/300/300','ytId':'Dughan Ko Bisaya karaoke'},
  {'title':'Kalipay','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/KalipayBisaya/300/300','ytId':'Kalipay Bisaya karaoke'},
  {'title':'Damgo','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/DamgoBisaya/300/300','ytId':'Damgo Bisaya karaoke'},
  {'title':'Naghulat Ko Nimo','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/NaghulatKoNimo/300/300','ytId':'Naghulat Ko Nimo Bisaya karaoke'},
  {'title':'Panagway','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/PanagwayBisaya/300/300','ytId':'Panagway Bisaya karaoke'},
  {'title':'Gikuptan Ko Ikaw','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/GikuptanKoIkaw/300/300','ytId':'Gikuptan Ko Ikaw Bisaya karaoke'},
  {'title':'Pabiling Nimo','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/PabilingNimo/300/300','ytId':'Pabiling Nimo Bisaya karaoke'},
  {'title':'Higugmaon Ta Ka','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/HigugmaonTaKa/300/300','ytId':'Higugmaon Ta Ka Bisaya karaoke'},
  {'title':'Ang Imong Pahiyom','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/AngImongPahiyom/300/300','ytId':'Ang Imong Pahiyom Bisaya karaoke'},
  {'title':'Adlaw Adlaw','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/AdlawAdlaw/300/300','ytId':'Adlaw Adlaw Bisaya karaoke'},
  {'title':'Pangako Ko Nimo','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/PangakoKoNimo/300/300','ytId':'Pangako Ko Nimo Bisaya karaoke'},
  {'title':'Tinuod Nga Gugma','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/TinuodNgaGugma/300/300','ytId':'Tinuod Nga Gugma Bisaya karaoke'},
  {'title':'Walay Katapusan','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/WalayKatapusan/300/300','ytId':'Walay Katapusan Bisaya karaoke'},
  {'title':'Bation Ko Gihapon','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/BationKoGihapon/300/300','ytId':'Bation Ko Gihapon Bisaya karaoke'},
  {'title':'Langit Sa Yuta','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/LangitSaYuta/300/300','ytId':'Langit Sa Yuta Bisaya karaoke'},
  {'title':'Habog Sa Gugma','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/HabogSaGugma/300/300','ytId':'Habog Sa Gugma Bisaya karaoke'},
  {'title':'Akong Kinabuhi','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/AkongKinabuhi/300/300','ytId':'Akong Kinabuhi Bisaya karaoke'},
  {'title':'Basta Naa Ka','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/BastaNaaKa/300/300','ytId':'Basta Naa Ka Bisaya karaoke'},
  {'title':'Gipangita Kita','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/GipangitaKita/300/300','ytId':'Gipangita Kita Bisaya karaoke'},
  {'title':'Sugat Ko Ikaw','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/SugatKoIkaw/300/300','ytId':'Sugat Ko Ikaw Bisaya karaoke'},
  {'title':'Inig-abot Mo','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/InigAbotMo/300/300','ytId':'Inig-abot Mo Bisaya karaoke'},
  {'title':'Pakighinabi','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/Pakighinabi/300/300','ytId':'Pakighinabi Bisaya karaoke'},
  {'title':'Ayaw Pagtalikod','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/AyawPagtalikod/300/300','ytId':'Ayaw Pagtalikod Bisaya karaoke'},
  {'title':'Kahiladman','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/KahiladmanBisaya/300/300','ytId':'Kahiladman Bisaya karaoke'},
  {'title':'Bag-ong Simula','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/BagonSimula/300/300','ytId':'Bag-ong Simula Bisaya karaoke'},
  {'title':'Magbalik Ka Na','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/MagbalikKaNaBisaya/300/300','ytId':'Magbalik Ka Na Bisaya karaoke'},
  {'title':'Dili Mapugngan','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/DiliMapugngan/300/300','ytId':'Dili Mapugngan Bisaya karaoke'},
  {'title':'Nagsalig Ko','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/NagsaligKo/300/300','ytId':'Nagsalig Ko Bisaya karaoke'},
  {'title':'Binuotan','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/BinuotanBisaya/300/300','ytId':'Binuotan Bisaya karaoke'},
  {'title':'Hapit Na Sab Pasko','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/HapitNaSabPasko/300/300','ytId':'Hapit Na Sab Pasko Bisaya karaoke'},
  {'title':'Maaga Sa Buntag','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/MaagaSaBuntag/300/300','ytId':'Maaga Sa Buntag Bisaya karaoke'},
  {'title':'Panaghugma','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/PanaghugmaBisaya/300/300','ytId':'Panaghugma Bisaya karaoke'},
  {'title':'Tinan-Awan Ko Ikaw','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/TinanAwanKoIkaw/300/300','ytId':'Tinan-Awan Ko Ikaw Bisaya karaoke'},
  {'title':'Sama-Sama Ra Kita','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/SamaSamaRaKita/300/300','ytId':'Sama-Sama Ra Kita Bisaya karaoke'},
  {'title':'Kining Tiansa','artist':'Various','genre':'Bisaya','image':'https://picsum.photos/seed/KiningTiansa/300/300','ytId':'Kining Tiansa Bisaya karaoke'},

  // ── OPM TAGALOG (120) ─────────────────────────────────────────────────────
  // Freddie Aguilar
  {'title':'Anak','artist':'Freddie Aguilar','genre':'OPM','image':'https://picsum.photos/seed/AnakFreddie/300/300','ytId':'Anak Freddie Aguilar karaoke'},
  {'title':'Pag-ibig Ko\'y Totoo','artist':'Freddie Aguilar','genre':'OPM','image':'https://picsum.photos/seed/PagibigKoyTotoo/300/300','ytId':'Pag-ibig Ko\'y Totoo Freddie Aguilar karaoke'},
  {'title':'Magdalena','artist':'Freddie Aguilar','genre':'OPM','image':'https://picsum.photos/seed/MagdalenaFreddie/300/300','ytId':'Magdalena Freddie Aguilar karaoke'},
  // Apo Hiking Society
  {'title':'Bukas Na Lang Kita Mamahalin','artist':'Apo Hiking Society','genre':'OPM','image':'https://picsum.photos/seed/BukasNaLangKita/300/300','ytId':'Bukas Na Lang Kita Mamahalin Apo Hiking Society karaoke'},
  {'title':'Panalangin','artist':'Apo Hiking Society','genre':'OPM','image':'https://picsum.photos/seed/PanalanginApo/300/300','ytId':'Panalangin Apo Hiking Society karaoke'},
  {'title':'Di Na Natuto','artist':'Apo Hiking Society','genre':'OPM','image':'https://picsum.photos/seed/DiNaNatuto/300/300','ytId':'Di Na Natuto Apo Hiking Society karaoke'},
  {'title':'Kay Ganda Ng Ating Musika','artist':'Apo Hiking Society','genre':'OPM','image':'https://picsum.photos/seed/KayGandaNgAting/300/300','ytId':'Kay Ganda Ng Ating Musika Apo Hiking Society karaoke'},
  {'title':'Mahiwagang Gabi','artist':'Apo Hiking Society','genre':'OPM','image':'https://picsum.photos/seed/MahiwagangGabi/300/300','ytId':'Mahiwagang Gabi Apo Hiking Society karaoke'},
  {'title':'Batang-Bata Ka Pa','artist':'Apo Hiking Society','genre':'OPM','image':'https://picsum.photos/seed/BatangBataKaPa/300/300','ytId':'Batang-Bata Ka Pa Apo Hiking Society karaoke'},
  {'title':'Pumapatak Ang Ulan','artist':'Apo Hiking Society','genre':'OPM','image':'https://picsum.photos/seed/PumapatakAngUlan/300/300','ytId':'Pumapatak Ang Ulan Apo Hiking Society karaoke'},
  {'title':'Natutulog Ba Ang Diyos','artist':'Apo Hiking Society','genre':'OPM','image':'https://picsum.photos/seed/NatutulogBaDiyos/300/300','ytId':'Natutulog Ba Ang Diyos Apo Hiking Society karaoke'},
  {'title':'Awit Ng Barkada','artist':'Apo Hiking Society','genre':'OPM','image':'https://picsum.photos/seed/AwitNgBarkada/300/300','ytId':'Awit Ng Barkada Apo Hiking Society karaoke'},
  {'title':'Even Just for One Night','artist':'Apo Hiking Society','genre':'OPM','image':'https://picsum.photos/seed/EvenJustOneNight/300/300','ytId':'Even Just for One Night Apo Hiking Society karaoke'},
  // Eraserheads
  {'title':'Huling El Bimbo','artist':'Eraserheads','genre':'OPM','image':'https://picsum.photos/seed/HulingElBimbo/300/300','ytId':'Huling El Bimbo Eraserheads karaoke'},
  {'title':'With a Smile','artist':'Eraserheads','genre':'OPM','image':'https://picsum.photos/seed/WithASmileEheads/300/300','ytId':'With a Smile Eraserheads karaoke'},
  {'title':'Alapaap','artist':'Eraserheads','genre':'OPM','image':'https://picsum.photos/seed/AlapaapEheads/300/300','ytId':'Alapaap Eraserheads karaoke'},
  {'title':'Sembreak','artist':'Eraserheads','genre':'OPM','image':'https://picsum.photos/seed/SembreakEheads/300/300','ytId':'Sembreak Eraserheads karaoke'},
  {'title':'Minsan','artist':'Eraserheads','genre':'OPM','image':'https://picsum.photos/seed/MinsanEheads/300/300','ytId':'Minsan Eraserheads karaoke'},
  {'title':'Overdrive','artist':'Eraserheads','genre':'OPM','image':'https://picsum.photos/seed/OverdriveEheads/300/300','ytId':'Overdrive Eraserheads karaoke'},
  {'title':'Magasin','artist':'Eraserheads','genre':'OPM','image':'https://picsum.photos/seed/MagasinEheads/300/300','ytId':'Magasin Eraserheads karaoke'},
  {'title':'Huwag Mo Na Sana','artist':'Eraserheads','genre':'OPM','image':'https://picsum.photos/seed/HuwagMoNaSana/300/300','ytId':'Huwag Mo Na Sana Eraserheads karaoke'},
  {'title':'Tindahan ni Aling Nena','artist':'Eraserheads','genre':'OPM','image':'https://picsum.photos/seed/TindahanNiAling/300/300','ytId':'Tindahan ni Aling Nena Eraserheads karaoke'},
  {'title':'Spolarium','artist':'Eraserheads','genre':'OPM','image':'https://picsum.photos/seed/SpolaEheads/300/300','ytId':'Spolarium Eraserheads karaoke'},
  // Sugarfree
  {'title':'Telepono','artist':'Sugarfree','genre':'OPM','image':'https://picsum.photos/seed/TeleponoSugarfree/300/300','ytId':'Telepono Sugarfree karaoke'},
  {'title':'Tulog Na','artist':'Sugarfree','genre':'OPM','image':'https://picsum.photos/seed/TulogNaSugarfree/300/300','ytId':'Tulog Na Sugarfree karaoke'},
  {'title':'Mariposa','artist':'Sugarfree','genre':'OPM','image':'https://picsum.photos/seed/MariposaS/300/300','ytId':'Mariposa Sugarfree karaoke'},
  {'title':'Sa Dulo Ng Walang Hanggan','artist':'Sugarfree','genre':'OPM','image':'https://picsum.photos/seed/SaDuloNgWalang/300/300','ytId':'Sa Dulo Ng Walang Hanggan Sugarfree karaoke'},
  {'title':'Burnout','artist':'Sugarfree','genre':'OPM','image':'https://picsum.photos/seed/BurnoutSugarfree/300/300','ytId':'Burnout Sugarfree karaoke'},
  {'title':'Wag Na Wag Mong Sasabihin','artist':'Sugarfree','genre':'OPM','image':'https://picsum.photos/seed/WagNaWagMong/300/300','ytId':'Wag Na Wag Mong Sasabihin Sugarfree karaoke'},
  // Parokya ni Edgar
  {'title':'Harana','artist':'Parokya ni Edgar','genre':'OPM','image':'https://picsum.photos/seed/HaranaPNE/300/300','ytId':'Harana Parokya ni Edgar karaoke'},
  {'title':'Silvertoes','artist':'Parokya ni Edgar','genre':'OPM','image':'https://picsum.photos/seed/SilvertoesPNE/300/300','ytId':'Silvertoes Parokya ni Edgar karaoke'},
  {'title':'Buloy','artist':'Parokya ni Edgar','genre':'OPM','image':'https://picsum.photos/seed/BuloyPNE/300/300','ytId':'Buloy Parokya ni Edgar karaoke'},
  {'title':'Picha Pie','artist':'Parokya ni Edgar','genre':'OPM','image':'https://picsum.photos/seed/PichaPiePNE/300/300','ytId':'Picha Pie Parokya ni Edgar karaoke'},
  {'title':'Gitara','artist':'Parokya ni Edgar','genre':'OPM','image':'https://picsum.photos/seed/GitaraPNE/300/300','ytId':'Gitara Parokya ni Edgar karaoke'},
  {'title':'The Yes Yes Show','artist':'Parokya ni Edgar','genre':'OPM','image':'https://picsum.photos/seed/YesYesShow/300/300','ytId':'The Yes Yes Show Parokya ni Edgar karaoke'},
  // Bamboo
  {'title':'Noypi','artist':'Bamboo','genre':'OPM','image':'https://picsum.photos/seed/NaypiBamboo/300/300','ytId':'Noypi Bamboo karaoke'},
  {'title':'Tatsulok','artist':'Bamboo','genre':'OPM','image':'https://picsum.photos/seed/TatsulokBamboo/300/300','ytId':'Tatsulok Bamboo karaoke'},
  {'title':'Masaya','artist':'Bamboo','genre':'OPM','image':'https://picsum.photos/seed/MasayaBamboo/300/300','ytId':'Masaya Bamboo karaoke'},
  {'title':'Mr. Clay','artist':'Bamboo','genre':'OPM','image':'https://picsum.photos/seed/MrClayBamboo/300/300','ytId':'Mr Clay Bamboo karaoke'},
  {'title':'Hallelujah','artist':'Bamboo','genre':'OPM','image':'https://picsum.photos/seed/HallelujahBamboo/300/300','ytId':'Hallelujah Bamboo karaoke'},
  // Hale
  {'title':'The Day You Said Goodnight','artist':'Hale','genre':'OPM','image':'https://picsum.photos/seed/TheDayYouSaidGoodnight/300/300','ytId':'The Day You Said Goodnight Hale karaoke'},
  {'title':'Broken Sonnet','artist':'Hale','genre':'OPM','image':'https://picsum.photos/seed/BrokenSonnetHale/300/300','ytId':'Broken Sonnet Hale karaoke'},
  {'title':'Be Careful','artist':'Hale','genre':'OPM','image':'https://picsum.photos/seed/BeCarefulHale/300/300','ytId':'Be Careful Hale karaoke'},
  // Rico Blanco
  {'title':'Your Universe','artist':'Rico Blanco','genre':'OPM','image':'https://picsum.photos/seed/YourUniverseRico/300/300','ytId':'Your Universe Rico Blanco karaoke'},
  {'title':'Antukin','artist':'Rico Blanco','genre':'OPM','image':'https://picsum.photos/seed/AntukinRico/300/300','ytId':'Antukin Rico Blanco karaoke'},
  {'title':'Complicated','artist':'Rico Blanco','genre':'OPM','image':'https://picsum.photos/seed/ComplicatedRico/300/300','ytId':'Complicated Rico Blanco karaoke'},
  // Freestyle
  {'title':'Dahil Mahal Kita','artist':'Freestyle','genre':'OPM','image':'https://picsum.photos/seed/DahilMahalKita/300/300','ytId':'Dahil Mahal Kita Freestyle karaoke'},
  {'title':'So Slow','artist':'Freestyle','genre':'OPM','image':'https://picsum.photos/seed/SoSlowFreestyle/300/300','ytId':'So Slow Freestyle karaoke'},
  {'title':'Take Me Away','artist':'Freestyle','genre':'OPM','image':'https://picsum.photos/seed/TakeMeAwayFreestyle/300/300','ytId':'Take Me Away Freestyle karaoke'},
  // Side A
  {'title':'Forevermore','artist':'Side A','genre':'OPM','image':'https://picsum.photos/seed/ForevermoreSideA/300/300','ytId':'Forevermore Side A karaoke'},
  {'title':'Give Me Your Forever','artist':'Side A','genre':'OPM','image':'https://picsum.photos/seed/GiveMeYourForever/300/300','ytId':'Give Me Your Forever Side A karaoke'},
  {'title':'Tell Me','artist':'Side A','genre':'OPM','image':'https://picsum.photos/seed/TellMeSideA/300/300','ytId':'Tell Me Side A karaoke'},
  // Gary Valenciano
  {'title':'Hataw Na','artist':'Gary Valenciano','genre':'OPM','image':'https://picsum.photos/seed/HatawNaGaryV/300/300','ytId':'Hataw Na Gary Valenciano karaoke'},
  {'title':'I Will Be Here','artist':'Gary Valenciano','genre':'OPM','image':'https://picsum.photos/seed/IWillBeHere/300/300','ytId':'I Will Be Here Gary Valenciano karaoke'},
  {'title':'Go!','artist':'Gary Valenciano','genre':'OPM','image':'https://picsum.photos/seed/GoGaryV/300/300','ytId':'Go Gary Valenciano karaoke'},
  {'title':'Di Bale Na Lang','artist':'Gary Valenciano','genre':'OPM','image':'https://picsum.photos/seed/DiBaleNaLang/300/300','ytId':'Di Bale Na Lang Gary Valenciano karaoke'},
  {'title':'Shout for Joy','artist':'Gary Valenciano','genre':'OPM','image':'https://picsum.photos/seed/ShoutForJoy/300/300','ytId':'Shout for Joy Gary Valenciano karaoke'},
  // Jose Mari Chan
  {'title':'Beautiful Girl','artist':'Jose Mari Chan','genre':'OPM','image':'https://picsum.photos/seed/BeautifulGirlJMC/300/300','ytId':'Beautiful Girl Jose Mari Chan karaoke'},
  {'title':'Can We Just Stop and Talk a While','artist':'Jose Mari Chan','genre':'OPM','image':'https://picsum.photos/seed/CanWeJustStop/300/300','ytId':'Can We Just Stop and Talk a While Jose Mari Chan karaoke'},
  {'title':'Constant Change','artist':'Jose Mari Chan','genre':'OPM','image':'https://picsum.photos/seed/ConstantChange/300/300','ytId':'Constant Change Jose Mari Chan karaoke'},
  {'title':'Miss Kita Kung Christmas','artist':'Jose Mari Chan','genre':'OPM','image':'https://picsum.photos/seed/MissKitaKung/300/300','ytId':'Miss Kita Kung Christmas Jose Mari Chan karaoke'},
  // Up Dharma Down
  {'title':'Tadhana','artist':'Up Dharma Down','genre':'OPM','image':'https://i.ytimg.com/vi/VHFRl7lGFRo/mqdefault.jpg','ytId':'VHFRl7lGFRo'},
  {'title':'Oo','artist':'Up Dharma Down','genre':'OPM','image':'https://picsum.photos/seed/OoUDD/300/300','ytId':'Oo Up Dharma Down karaoke'},
  {'title':'Indak','artist':'Up Dharma Down','genre':'OPM','image':'https://picsum.photos/seed/IndakUDD/300/300','ytId':'Indak Up Dharma Down karaoke'},
  {'title':'Sigurado','artist':'Up Dharma Down','genre':'OPM','image':'https://picsum.photos/seed/SiguradoUDD/300/300','ytId':'Sigurado Up Dharma Down karaoke'},
  // Modern OPM
  {'title':'Kung Di Rin Lang Ikaw','artist':'December Avenue ft. Moira Dela Torre','genre':'OPM','image':'https://picsum.photos/seed/KungDiRinLangIkaw/300/300','ytId':'Kung Di Rin Lang Ikaw December Avenue Moira karaoke'},
  {'title':'Bulong','artist':'December Avenue','genre':'OPM','image':'https://picsum.photos/seed/BulongDecember/300/300','ytId':'Bulong December Avenue karaoke'},
  {'title':'Sa Ngalan Ng Pag-ibig','artist':'December Avenue','genre':'OPM','image':'https://picsum.photos/seed/SaNgalanNgPagibig/300/300','ytId':'Sa Ngalan Ng Pag-ibig December Avenue karaoke'},
  {'title':'Sana','artist':'I Belong to the Zoo','genre':'OPM','image':'https://i.ytimg.com/vi/R8j3JQAEBAY/mqdefault.jpg','ytId':'R8j3JQAEBAY'},
  {'title':'Kabataan','artist':'I Belong to the Zoo','genre':'OPM','image':'https://picsum.photos/seed/KabataanIBTTZ/300/300','ytId':'Kabataan I Belong to the Zoo karaoke'},
  {'title':'Kilometro','artist':'Unique Salonga','genre':'OPM','image':'https://i.ytimg.com/vi/FjTMdXhFBKU/mqdefault.jpg','ytId':'FjTMdXhFBKU'},
  {'title':'Sandali','artist':'Unique Salonga','genre':'OPM','image':'https://picsum.photos/seed/SandaliUnique/300/300','ytId':'Sandali Unique Salonga karaoke'},
  {'title':'Dati','artist':'Sam Concepcion ft. Tippy Dos Santos','genre':'OPM','image':'https://picsum.photos/seed/DatiSamConcepcion/300/300','ytId':'Dati Sam Concepcion Tippy Dos Santos karaoke'},
  {'title':'Dadalhin','artist':'Regine Velasquez','genre':'OPM','image':'https://i.ytimg.com/vi/dv-FqL0KTZE/mqdefault.jpg','ytId':'dv-FqL0KTZE'},
  {'title':'Sana Maulit Muli','artist':'Regine Velasquez','genre':'OPM','image':'https://picsum.photos/seed/SanaMaulit/300/300','ytId':'Sana Maulit Muli Regine Velasquez karaoke'},
  {'title':'Kahit Maputi Na Ang Buhok Ko','artist':'Rey Valera','genre':'OPM','image':'https://i.ytimg.com/vi/UxAX0RjxBeM/mqdefault.jpg','ytId':'UxAX0RjxBeM'},
  {'title':'Lahat Ng Bagay','artist':'Rey Valera','genre':'OPM','image':'https://picsum.photos/seed/LahatNgBagay/300/300','ytId':'Lahat Ng Bagay Rey Valera karaoke'},
  {'title':'Habang May Buhay','artist':'Rey Valera','genre':'OPM','image':'https://picsum.photos/seed/HabangMayBuhay/300/300','ytId':'Habang May Buhay Rey Valera karaoke'},
  {'title':'Pangarap Ko Ang Ibigin Ka','artist':'Rey Valera','genre':'OPM','image':'https://picsum.photos/seed/PangarapKoAng/300/300','ytId':'Pangarap Ko Ang Ibigin Ka Rey Valera karaoke'},

  // ── LOVE SONGS (90) ────────────────────────────────────────────────────────
  // Regine Velasquez
  {'title':'Kailangan Kita','artist':'Regine Velasquez','genre':'Love','image':'https://picsum.photos/seed/KailanganKita/300/300','ytId':'Kailangan Kita Regine Velasquez karaoke'},
  {'title':'Urong Sulong','artist':'Regine Velasquez','genre':'Love','image':'https://picsum.photos/seed/UrongSulong/300/300','ytId':'Urong Sulong Regine Velasquez karaoke'},
  {'title':'Kung Sakali Man','artist':'Regine Velasquez','genre':'Love','image':'https://picsum.photos/seed/KungSakaliMan/300/300','ytId':'Kung Sakali Man Regine Velasquez karaoke'},
  {'title':'Loving You','artist':'Regine Velasquez','genre':'Love','image':'https://picsum.photos/seed/LovingYouRegine/300/300','ytId':'Loving You Regine Velasquez karaoke'},
  {'title':'Kung Tayo Nalang','artist':'Regine Velasquez','genre':'Love','image':'https://picsum.photos/seed/KungTayoNalang/300/300','ytId':'Kung Tayo Nalang Regine Velasquez karaoke'},
  // Martin Nievera
  {'title':'Kung Kailangan Mo Ako','artist':'Martin Nievera','genre':'Love','image':'https://picsum.photos/seed/KungKailangan/300/300','ytId':'Kung Kailangan Mo Ako Martin Nievera karaoke'},
  {'title':'You Are My Song','artist':'Martin Nievera','genre':'Love','image':'https://picsum.photos/seed/YouAreMySONg/300/300','ytId':'You Are My Song Martin Nievera karaoke'},
  {'title':'Can\'t Stop Loving You','artist':'Martin Nievera','genre':'Love','image':'https://picsum.photos/seed/CantStopLoving/300/300','ytId':'Cant Stop Loving You Martin Nievera karaoke'},
  {'title':'Be My Lady','artist':'Martin Nievera','genre':'Love','image':'https://picsum.photos/seed/BeMyLadyMartin/300/300','ytId':'Be My Lady Martin Nievera karaoke'},
  {'title':'Ikaw Lamang','artist':'Martin Nievera','genre':'Love','image':'https://picsum.photos/seed/IkawLamangMartin/300/300','ytId':'Ikaw Lamang Martin Nievera karaoke'},
  // Ogie Alcasid
  {'title':'Nandito Ako','artist':'Ogie Alcasid','genre':'Love','image':'https://picsum.photos/seed/NanditoAkoOgie/300/300','ytId':'Nandito Ako Ogie Alcasid karaoke'},
  {'title':'Kung Mawawala Ka','artist':'Ogie Alcasid','genre':'Love','image':'https://picsum.photos/seed/KungMawawalaKa/300/300','ytId':'Kung Mawawala Ka Ogie Alcasid karaoke'},
  {'title':'Ilaw Ng Tahanan','artist':'Ogie Alcasid','genre':'Love','image':'https://picsum.photos/seed/IlawNgTahanan/300/300','ytId':'Ilaw Ng Tahanan Ogie Alcasid karaoke'},
  // Yeng Constantino
  {'title':'Hawak Kamay','artist':'Yeng Constantino','genre':'Love','image':'https://i.ytimg.com/vi/tRv7jGEqeqI/mqdefault.jpg','ytId':'tRv7jGEqeqI'},
  {'title':'Salamat','artist':'Yeng Constantino','genre':'Love','image':'https://picsum.photos/seed/SalamatYeng/300/300','ytId':'Salamat Yeng Constantino karaoke'},
  {'title':'Nag-iisa','artist':'Yeng Constantino','genre':'Love','image':'https://picsum.photos/seed/NagIisaYeng/300/300','ytId':'Nag-iisa Yeng Constantino karaoke'},
  {'title':'One in a Million','artist':'Yeng Constantino','genre':'Love','image':'https://picsum.photos/seed/OneInAMillion/300/300','ytId':'One in a Million Yeng Constantino karaoke'},
  // Kyla
  {'title':'Hanggang','artist':'Kyla','genre':'Love','image':'https://picsum.photos/seed/HangganKyla/300/300','ytId':'Hanggang Kyla karaoke'},
  {'title':'Nadarama','artist':'Kyla','genre':'Love','image':'https://picsum.photos/seed/NadaramaKyla/300/300','ytId':'Nadarama Kyla karaoke'},
  {'title':'Tell Me Where It Hurts','artist':'Kyla','genre':'Love','image':'https://picsum.photos/seed/TellMeWhereKyla/300/300','ytId':'Tell Me Where It Hurts Kyla karaoke'},
  {'title':'I Fall In Love','artist':'Kyla','genre':'Love','image':'https://picsum.photos/seed/IFallInLoveKyla/300/300','ytId':'I Fall In Love Kyla karaoke'},
  {'title':'Pag-ibig','artist':'Kyla','genre':'Love','image':'https://picsum.photos/seed/PagibigKyla/300/300','ytId':'Pag-ibig Kyla karaoke'},
  // Ben&Ben
  {'title':'Maybe The Night','artist':'Ben&Ben','genre':'Love','image':'https://picsum.photos/seed/MaybeTheNight/300/300','ytId':'Maybe The Night Ben Ben karaoke'},
  {'title':'Kathang Isip','artist':'Ben&Ben','genre':'Love','image':'https://picsum.photos/seed/KathangIsip/300/300','ytId':'Kathang Isip Ben Ben karaoke'},
  {'title':'Di Ka Sayang','artist':'Ben&Ben','genre':'Love','image':'https://picsum.photos/seed/DiKaSayang/300/300','ytId':'Di Ka Sayang Ben Ben karaoke'},
  {'title':'Leaves','artist':'Ben&Ben','genre':'Love','image':'https://picsum.photos/seed/LeavesBenBen/300/300','ytId':'Leaves Ben Ben karaoke'},
  {'title':'Araw-Araw','artist':'Ben&Ben','genre':'Love','image':'https://picsum.photos/seed/ArawArawBenBen/300/300','ytId':'Araw-Araw Ben Ben karaoke'},
  {'title':'Lifetime','artist':'Ben&Ben','genre':'Love','image':'https://picsum.photos/seed/LifetimeBenBen/300/300','ytId':'Lifetime Ben Ben karaoke'},
  // Moira Dela Torre
  {'title':'Paubaya','artist':'Moira Dela Torre','genre':'Love','image':'https://picsum.photos/seed/PaubayaMoira/300/300','ytId':'Paubaya Moira Dela Torre karaoke'},
  {'title':'Tagpuan','artist':'Moira Dela Torre','genre':'Love','image':'https://picsum.photos/seed/TagpuanMoira/300/300','ytId':'Tagpuan Moira Dela Torre karaoke'},
  {'title':'Ikaw At Ako','artist':'Moira Dela Torre','genre':'Love','image':'https://picsum.photos/seed/IkawAtAko/300/300','ytId':'Ikaw At Ako Moira Dela Torre karaoke'},
  {'title':'Kumpas','artist':'Moira Dela Torre','genre':'Love','image':'https://picsum.photos/seed/KumpasMoira/300/300','ytId':'Kumpas Moira Dela Torre karaoke'},
  {'title':'Malaya','artist':'Moira Dela Torre','genre':'Love','image':'https://picsum.photos/seed/MalayaMoira/300/300','ytId':'Malaya Moira Dela Torre karaoke'},
  // December Avenue
  {'title':'Kahit Ayaw Mo Na','artist':'This Band','genre':'Love','image':'https://picsum.photos/seed/KahitAyawMoNa/300/300','ytId':'Kahit Ayaw Mo Na This Band karaoke'},
  {'title':'Till I Met You','artist':'Ebe Dancel','genre':'Love','image':'https://picsum.photos/seed/TillIMetYouEbe/300/300','ytId':'Till I Met You Ebe Dancel karaoke'},
  {'title':'Nasa Iyo Na Ang Lahat','artist':'Daniel Padilla','genre':'Love','image':'https://images.genius.com/e817d67292e5c1ac1e72b0c8573161e5.900x900x1.jpg','ytId':'Nasa Iyo Na Ang Lahat Daniel Padilla karaoke'},
  {'title':'Mahal Kita Walang Iba','artist':'Michael V','genre':'Love','image':'https://picsum.photos/seed/MahalKitaWalangIba/300/300','ytId':'Mahal Kita Walang Iba Michael V karaoke'},
  {'title':'Kay Tagal Kang Hinintay','artist':'Pops Fernandez','genre':'Love','image':'https://picsum.photos/seed/KayTagalKang/300/300','ytId':'Kay Tagal Kang Hinintay Pops Fernandez karaoke'},
  {'title':'Tukso','artist':'Pops Fernandez','genre':'Love','image':'https://picsum.photos/seed/TuksoPops/300/300','ytId':'Tukso Pops Fernandez karaoke'},
  {'title':'Ngayon At Kailanman','artist':'Basil Valdez','genre':'Love','image':'https://picsum.photos/seed/NgayonAtKailanman/300/300','ytId':'Ngayon At Kailanman Basil Valdez karaoke'},
  {'title':'Isang Linggong Pag-ibig','artist':'Imelda Papin','genre':'Love','image':'https://picsum.photos/seed/IsangLinggong/300/300','ytId':'Isang Linggong Pag-ibig Imelda Papin karaoke'},
  {'title':'Mahal Ko O Mahal Ako','artist':'Imelda Papin','genre':'Love','image':'https://picsum.photos/seed/MahalKoOMahalAko/300/300','ytId':'Mahal Ko O Mahal Ako Imelda Papin karaoke'},
  {'title':'Kung Alam Mo Lang','artist':'December Avenue','genre':'Love','image':'https://picsum.photos/seed/KungAlamMoLang/300/300','ytId':'Kung Alam Mo Lang December Avenue karaoke'},
  {'title':'Pano','artist':'Ron Pope ft. December Avenue','genre':'Love','image':'https://picsum.photos/seed/PanoDecember/300/300','ytId':'Pano Ron Pope December Avenue karaoke'},
  {'title':'Dalaga','artist':'Juris','genre':'Love','image':'https://picsum.photos/seed/DalagaJuris/300/300','ytId':'Dalaga Juris karaoke'},
  {'title':'Sa Susunod Na Habang Buhay','artist':'Juris','genre':'Love','image':'https://picsum.photos/seed/SaSusunodNa/300/300','ytId':'Sa Susunod Na Habang Buhay Juris karaoke'},
  {'title':'Dito Sa Puso Ko','artist':'Various','genre':'Love','image':'https://picsum.photos/seed/DitoSaPusoKo/300/300','ytId':'Dito Sa Puso Ko OPM karaoke'},
  {'title':'Ikaw Pala','artist':'Itchyworms','genre':'Love','image':'https://picsum.photos/seed/IkawPalaItchyworms/300/300','ytId':'Ikaw Pala Itchyworms karaoke'},
  {'title':'Akin Ka Na Lang','artist':'Itchyworms','genre':'Love','image':'https://picsum.photos/seed/AkinKaNaLang/300/300','ytId':'Akin Ka Na Lang Itchyworms karaoke'},
  {'title':'Pag-ibig Sa Tingin','artist':'MYMP','genre':'Love','image':'https://picsum.photos/seed/PagibigSaTingin/300/300','ytId':'Pag-ibig Sa Tingin MYMP karaoke'},
  {'title':'No One Else','artist':'MYMP','genre':'Love','image':'https://picsum.photos/seed/NoOneElseMYMP/300/300','ytId':'No One Else MYMP karaoke'},
  {'title':'Sana Ngayong Pasko','artist':'Various','genre':'Love','image':'https://picsum.photos/seed/SanaNgayong/300/300','ytId':'Sana Ngayong Pasko OPM karaoke'},
  {'title':'Alaala','artist':'Juan Karlos','genre':'Love','image':'https://picsum.photos/seed/AalaalaJK/300/300','ytId':'Alaala Juan Karlos karaoke'},
  {'title':'Dati Pa','artist':'Arthur Nery','genre':'Love','image':'https://picsum.photos/seed/DatiPaArthur/300/300','ytId':'Dati Pa Arthur Nery karaoke'},
  {'title':'Palagi','artist':'Arthur Nery ft. Jason Dhakal','genre':'Love','image':'https://picsum.photos/seed/PalagiArthur/300/300','ytId':'Palagi Arthur Nery karaoke'},
  {'title':'Habang Buhay','artist':'Zephanie','genre':'Love','image':'https://picsum.photos/seed/HabangBuhayZ/300/300','ytId':'Habang Buhay Zephanie karaoke'},
  {'title':'Binibini','artist':'Arthur Nery','genre':'Love','image':'https://i.pinimg.com/736x/c4/51/fd/c451fd1b67b8e80830aaca56188e46d8.jpg','ytId':'Binibini Arthur Nery karaoke'},
  {'title':'Puso Ko\'y Sayo','artist':'Various','genre':'Love','image':'https://picsum.photos/seed/PusoKoySayo/300/300','ytId':'Puso Ko y Sayo OPM love karaoke'},
  {'title':'Hiling','artist':'Callalily','genre':'Love','image':'https://picsum.photos/seed/HilingCallalily/300/300','ytId':'Hiling Callalily karaoke'},
  {'title':'Magpakailanman','artist':'Jed Madela','genre':'Love','image':'https://picsum.photos/seed/MagpakailanmanJed/300/300','ytId':'Magpakailanman Jed Madela karaoke'},
  {'title':'Forever\'s Not Enough','artist':'Sarah Geronimo','genre':'Love','image':'https://picsum.photos/seed/ForeversNotEnough/300/300','ytId':'Forever\'s Not Enough Sarah Geronimo karaoke'},
  {'title':'Mabagal','artist':'Daniel Padilla ft. Moira Dela Torre','genre':'Love','image':'https://picsum.photos/seed/MabagalDanielPadilla/300/300','ytId':'Mabagal Daniel Padilla Moira karaoke'},
  {'title':'Buwan','artist':'Juan Karlos','genre':'Love','image':'https://picsum.photos/seed/BuwanJuanKarlos/300/300','ytId':'Buwan Juan Karlos karaoke'},
  {'title':'Mundo','artist':'IV of Spades','genre':'Love','image':'https://picsum.photos/seed/MundoIVofSpades/300/300','ytId':'Mundo IV of Spades karaoke'},
  {'title':'Dilaw','artist':'Maki','genre':'Love','image':'https://picsum.photos/seed/DilawMaki/300/300','ytId':'Dilaw Maki karaoke'},
  {'title':'Ere','artist':'Juan Karlos','genre':'Love','image':'https://picsum.photos/seed/EreJuanKarlos/300/300','ytId':'Ere Juan Karlos karaoke'},
  {'title':'Pagtingin','artist':'Ben&Ben','genre':'Love','image':'https://picsum.photos/seed/PagtiningBenBen/300/300','ytId':'Pagtingin Ben Ben karaoke'},
  {'title':'Fallen','artist':'Lola Amour','genre':'Love','image':'https://images.genius.com/b62c08396330faf55dae7e6a73b26324.1000x1000x1.png','ytId':'Fallen Lola Amour karaoke'},
  {'title':'Mahika','artist':'Unique Salonga ft. June Marieezy','genre':'Love','image':'https://picsum.photos/seed/MahikaUnique/300/300','ytId':'Mahika Unique Salonga karaoke'},
  {'title':'Raining in Manila','artist':'Lola Amour','genre':'Love','image':'https://picsum.photos/seed/RainingInManila/300/300','ytId':'Raining in Manila Lola Amour karaoke'},
  {'title':'Mundo\'y Akin','artist':'Ben&Ben','genre':'Love','image':'https://picsum.photos/seed/MundoYAkin/300/300','ytId':'Mundo\'y Akin Ben Ben karaoke'},
  {'title':'Paalam','artist':'Moira ft. Jason Dhakal','genre':'Love','image':'https://picsum.photos/seed/PaalamMoiraJason/300/300','ytId':'Paalam Moira Jason Dhakal karaoke'},

  // ── POP (100) ─────────────────────────────────────────────────────────────
  {'title':'Ikaw','artist':'Yeng Constantino','genre':'Pop','image':'https://i.ytimg.com/vi/iOKMTuEhJBc/mqdefault.jpg','ytId':'iOKMTuEhJBc'},
  {'title':'GENTO','artist':'SB19','genre':'Pop','image':'https://picsum.photos/seed/GENTOsb19/300/300','ytId':'GENTO SB19 karaoke'},
  {'title':'MAPA','artist':'SB19','genre':'Pop','image':'https://picsum.photos/seed/MAPAsb19/300/300','ytId':'MAPA SB19 karaoke'},
  {'title':'Alab','artist':'SB19','genre':'Pop','image':'https://picsum.photos/seed/AlabSB19/300/300','ytId':'Alab SB19 karaoke'},
  {'title':'Go Up','artist':'SB19','genre':'Pop','image':'https://picsum.photos/seed/GoUpSB19/300/300','ytId':'Go Up SB19 karaoke'},
  {'title':'Dungaw','artist':'SB19','genre':'Pop','image':'https://picsum.photos/seed/DungawSB19/300/300','ytId':'Dungaw SB19 karaoke'},
  {'title':'Tala','artist':'Sarah Geronimo','genre':'Pop','image':'https://picsum.photos/seed/TalaSarahG/300/300','ytId':'Tala Sarah Geronimo karaoke'},
  {'title':'Ikot Ikot','artist':'Sarah Geronimo','genre':'Pop','image':'https://picsum.photos/seed/IkotIkotSarahG/300/300','ytId':'Ikot Ikot Sarah Geronimo karaoke'},
  {'title':'Lumapit Sa Akin','artist':'Sarah Geronimo','genre':'Pop','image':'https://picsum.photos/seed/LumapitSaAkin/300/300','ytId':'Lumapit Sa Akin Sarah Geronimo karaoke'},
  {'title':'Randomantic','artist':'James Reid','genre':'Pop','image':'https://picsum.photos/seed/RandomanticJames/300/300','ytId':'Randomantic James Reid karaoke'},
  {'title':'Lie to Me','artist':'James Reid','genre':'Pop','image':'https://picsum.photos/seed/LieToMeJames/300/300','ytId':'Lie to Me James Reid karaoke'},
  {'title':'This Time','artist':'Darren Espanto','genre':'Pop','image':'https://picsum.photos/seed/ThisTimeDarren/300/300','ytId':'This Time Darren Espanto karaoke'},
  {'title':'Ikaw Kasi','artist':'Darren Espanto','genre':'Pop','image':'https://picsum.photos/seed/IkawKasiDarren/300/300','ytId':'Ikaw Kasi Darren Espanto karaoke'},
  {'title':'Ikaw Lamang','artist':'Zephanie','genre':'Pop','image':'https://picsum.photos/seed/IkawLamangZ/300/300','ytId':'Ikaw Lamang Zephanie karaoke'},
  {'title':'Stand By Me','artist':'Zephanie','genre':'Pop','image':'https://picsum.photos/seed/StandByMeZ/300/300','ytId':'Stand By Me Zephanie karaoke'},
  {'title':'Upuan','artist':'Gloc-9','genre':'Pop','image':'https://picsum.photos/seed/UpuanGloc9/300/300','ytId':'Upuan Gloc-9 karaoke'},
  {'title':'Sirena','artist':'Sarah Geronimo','genre':'Pop','image':'https://picsum.photos/seed/SirenaSarahG/300/300','ytId':'Sirena Sarah Geronimo karaoke'},
  {'title':'Pag-ibig Totoong Mahal','artist':'Various','genre':'Pop','image':'https://picsum.photos/seed/PagibigTotoong/300/300','ytId':'Pag-ibig Totoong Mahal OPM pop karaoke'},
  {'title':'Doon Lang','artist':'Imago','genre':'Pop','image':'https://picsum.photos/seed/DoonLangImago/300/300','ytId':'Doon Lang Imago karaoke'},
  {'title':'Sundo','artist':'Imago','genre':'Pop','image':'https://picsum.photos/seed/SundoImago/300/300','ytId':'Sundo Imago karaoke'},
  {'title':'Akap','artist':'Imago','genre':'Pop','image':'https://picsum.photos/seed/AkapImago/300/300','ytId':'Akap Imago karaoke'},
  {'title':'Kay Tagal','artist':'Jed Madela','genre':'Pop','image':'https://picsum.photos/seed/KayTagalJed/300/300','ytId':'Kay Tagal Jed Madela karaoke'},
  {'title':'Ikaw','artist':'Bugoy Drilon','genre':'Pop','image':'https://picsum.photos/seed/IkawBugoy/300/300','ytId':'Ikaw Bugoy Drilon karaoke'},
  {'title':'Bituin','artist':'Zsa Zsa Padilla','genre':'Pop','image':'https://picsum.photos/seed/BituinZsaZsa/300/300','ytId':'Bituin Zsa Zsa Padilla karaoke'},
  {'title':'Bakit Ba Ikaw','artist':'Zsa Zsa Padilla','genre':'Pop','image':'https://picsum.photos/seed/BakitBaIkaw/300/300','ytId':'Bakit Ba Ikaw Zsa Zsa Padilla karaoke'},
  {'title':'Maging Sino Ka Man','artist':'Jose Mari Chan','genre':'Pop','image':'https://picsum.photos/seed/MagingSinoKa/300/300','ytId':'Maging Sino Ka Man Jose Mari Chan karaoke'},
  {'title':'Paano','artist':'TJ Monterde','genre':'Pop','image':'https://picsum.photos/seed/PaanoTJMonterde/300/300','ytId':'Paano TJ Monterde karaoke'},
  {'title':'Ikaw Nga','artist':'TJ Monterde','genre':'Pop','image':'https://picsum.photos/seed/IkawNgaTJ/300/300','ytId':'Ikaw Nga TJ Monterde karaoke'},
  {'title':'Kung Wala Ka','artist':'TJ Monterde','genre':'Pop','image':'https://picsum.photos/seed/KungWalaKaTJ/300/300','ytId':'Kung Wala Ka TJ Monterde karaoke'},
  {'title':'Ikaw Lang','artist':'TJ Monterde','genre':'Pop','image':'https://picsum.photos/seed/IkawLangTJ/300/300','ytId':'Ikaw Lang TJ Monterde karaoke'},
  {'title':'Kahit Kailan','artist':'South Border','genre':'Pop','image':'https://picsum.photos/seed/KahitKailanSB/300/300','ytId':'Kahit Kailan South Border karaoke'},
  {'title':'Rainbow','artist':'South Border','genre':'Pop','image':'https://picsum.photos/seed/RainbowSouthBorder/300/300','ytId':'Rainbow South Border karaoke'},
  {'title':'Love of My Life','artist':'South Border','genre':'Pop','image':'https://picsum.photos/seed/LoveOfMyLifeSB/300/300','ytId':'Love of My Life South Border karaoke'},
  {'title':'Pag-ibig','artist':'Moira Dela Torre','genre':'Pop','image':'https://picsum.photos/seed/PagibigMoiraPop/300/300','ytId':'Pag-ibig Moira Dela Torre karaoke'},
  {'title':'Torete','artist':'Moonstar88','genre':'Pop','image':'https://picsum.photos/seed/ToreteMoon88Pop/300/300','ytId':'Torete Moonstar88 karaoke'},
  {'title':'Migraine','artist':'Moonstar88','genre':'Pop','image':'https://picsum.photos/seed/MigraineMoon88/300/300','ytId':'Migraine Moonstar88 karaoke'},
  {'title':'Sulat','artist':'Moonstar88','genre':'Pop','image':'https://picsum.photos/seed/SulatMoon88/300/300','ytId':'Sulat Moonstar88 karaoke'},
  {'title':'Pano','artist':'Moonstar88','genre':'Pop','image':'https://picsum.photos/seed/PanoMoon88/300/300','ytId':'Pano Moonstar88 karaoke'},
  {'title':'Kung Ayaw Mo Na','artist':'Rivermaya','genre':'Pop','image':'https://picsum.photos/seed/KungAyawMoNa/300/300','ytId':'Kung Ayaw Mo Na Rivermaya karaoke'},
  {'title':'Elesi','artist':'Rivermaya','genre':'Pop','image':'https://picsum.photos/seed/ElesiRivermaya/300/300','ytId':'Elesi Rivermaya karaoke'},
  {'title':'You\'ll Be Safe Here','artist':'Rivermaya','genre':'Pop','image':'https://picsum.photos/seed/YoullBeSafeHere/300/300','ytId':'You\'ll Be Safe Here Rivermaya karaoke'},
  {'title':'Hinahanap-hanap Kita','artist':'Rivermaya','genre':'Pop','image':'https://picsum.photos/seed/HinahanapHanap/300/300','ytId':'Hinahanap-hanap Kita Rivermaya karaoke'},
  {'title':'Dear God','artist':'Calla Lily','genre':'Pop','image':'https://picsum.photos/seed/DearGodCalla/300/300','ytId':'Dear God Calla Lily karaoke'},
  {'title':'Clueless','artist':'KZ Tandingan','genre':'Pop','image':'https://picsum.photos/seed/CluelessKZ/300/300','ytId':'Clueless KZ Tandingan karaoke'},
  {'title':'Sariling Multo','artist':'KZ Tandingan','genre':'Pop','image':'https://picsum.photos/seed/SarilingMulto/300/300','ytId':'Sariling Multo KZ Tandingan karaoke'},
  {'title':'Your Love','artist':'Alamid','genre':'Pop','image':'https://picsum.photos/seed/YourLoveAlamid/300/300','ytId':'Your Love Alamid karaoke'},
  {'title':'Perfect Love','artist':'Rockstar','genre':'Pop','image':'https://picsum.photos/seed/PerfectLoveRS/300/300','ytId':'Perfect Love Rockstar karaoke'},
  {'title':'Huwag Na Huwag Mong Sasabihin','artist':'Moonstar88','genre':'Pop','image':'https://picsum.photos/seed/HuwagNaHuwag/300/300','ytId':'Huwag Na Huwag Mong Sasabihin Moonstar88 karaoke'},
  {'title':'Ngiti','artist':'Chicser','genre':'Pop','image':'https://picsum.photos/seed/NgitiChicser/300/300','ytId':'Ngiti Chicser karaoke'},
  {'title':'Tayong Dalawa','artist':'Juris ft. Kyla','genre':'Pop','image':'https://picsum.photos/seed/TayongDalawa/300/300','ytId':'Tayong Dalawa Juris Kyla karaoke'},
  {'title':'Bakit Ngayon Ka Lang','artist':'Martin Nievera','genre':'Pop','image':'https://picsum.photos/seed/BakitNgayon/300/300','ytId':'Bakit Ngayon Ka Lang Martin Nievera karaoke'},
  {'title':'Naway Lagi','artist':'Sheryn Regis','genre':'Pop','image':'https://picsum.photos/seed/NawayLagi/300/300','ytId':'Naway Lagi Sheryn Regis karaoke'},
  {'title':'Nosi Ba Lasi','artist':'Yoyoy Villame','genre':'Pop','image':'https://picsum.photos/seed/NosiBalasi2/300/300','ytId':'Nosi Ba Lasi Tagalog karaoke'},
  {'title':'Someday','artist':'Brownman Revival','genre':'Pop','image':'https://picsum.photos/seed/SomedayBrownman/300/300','ytId':'Someday Brownman Revival karaoke'},
  {'title':'Doo Bee Doo','artist':'Brownman Revival','genre':'Pop','image':'https://picsum.photos/seed/DooBeeDoo/300/300','ytId':'Doo Bee Doo Brownman Revival karaoke'},
  {'title':'Tell Me','artist':'Silent Sanctuary','genre':'Pop','image':'https://picsum.photos/seed/TellMeSilent/300/300','ytId':'Tell Me Silent Sanctuary karaoke'},
  {'title':'Sa Ngalan Ng Pagmamahal','artist':'Silent Sanctuary','genre':'Pop','image':'https://picsum.photos/seed/SaNgalanSilent/300/300','ytId':'Sa Ngalan Ng Pagmamahal Silent Sanctuary karaoke'},
  {'title':'Pasensya Ka Na','artist':'Silent Sanctuary','genre':'Pop','image':'https://picsum.photos/seed/PasensyaKaNa/300/300','ytId':'Pasensya Ka Na Silent Sanctuary karaoke'},
  {'title':'Oras','artist':'Silent Sanctuary','genre':'Pop','image':'https://picsum.photos/seed/OrasSilent/300/300','ytId':'Oras Silent Sanctuary karaoke'},
  {'title':'Pag-ibig Nga Naman','artist':'Various','genre':'Pop','image':'https://picsum.photos/seed/PagibigNgaNaman/300/300','ytId':'Pag-ibig Nga Naman OPM pop karaoke'},
  {'title':'Habang Buhay','artist':'Jed Madela','genre':'Pop','image':'https://picsum.photos/seed/HabangBuhayJed/300/300','ytId':'Habang Buhay Jed Madela karaoke'},
  {'title':'Ibigin Mo Ako','artist':'Regine Velasquez','genre':'Pop','image':'https://picsum.photos/seed/IbiginMoAko/300/300','ytId':'Ibigin Mo Ako Regine Velasquez karaoke'},
  {'title':'Babalik Ka Rin','artist':'Regine Velasquez','genre':'Pop','image':'https://picsum.photos/seed/BabalikKaRin/300/300','ytId':'Babalik Ka Rin Regine Velasquez karaoke'},
  {'title':'Walang Hanggang Paalam','artist':'Various','genre':'Pop','image':'https://picsum.photos/seed/WalangHanggang/300/300','ytId':'Walang Hanggang Paalam OPM pop karaoke'},
  {'title':'Maging Akin','artist':'Various','genre':'Pop','image':'https://picsum.photos/seed/MagingAkin/300/300','ytId':'Maging Akin OPM pop karaoke'},
  {'title':'Saan Ka Man Naroroon','artist':'Martin Nievera','genre':'Pop','image':'https://picsum.photos/seed/SaanKaManNaroon/300/300','ytId':'Saan Ka Man Naroroon Martin Nievera karaoke'},
  {'title':'Mangarap Ka','artist':'Erik Santos','genre':'Pop','image':'https://picsum.photos/seed/MangarapKaErik/300/300','ytId':'Mangarap Ka Erik Santos karaoke'},
  {'title':'Ikaw Ang Aking Mahal','artist':'Erik Santos','genre':'Pop','image':'https://picsum.photos/seed/IkawAngAkingMahal/300/300','ytId':'Ikaw Ang Aking Mahal Erik Santos karaoke'},
  {'title':'You Are My Everything','artist':'Erik Santos','genre':'Pop','image':'https://picsum.photos/seed/YouAreMyEverything/300/300','ytId':'You Are My Everything Erik Santos karaoke'},
  {'title':'Pusong Bato','artist':'Lani Misalucha','genre':'Pop','image':'https://picsum.photos/seed/PusongBatoLani/300/300','ytId':'Pusong Bato Lani Misalucha karaoke'},
  {'title':'La Vida','artist':'Lani Misalucha','genre':'Pop','image':'https://picsum.photos/seed/LaVidaLani/300/300','ytId':'La Vida Lani Misalucha karaoke'},
  {'title':'Bakit','artist':'Carol Banawa','genre':'Pop','image':'https://picsum.photos/seed/BakitCarol/300/300','ytId':'Bakit Carol Banawa karaoke'},
  {'title':'Kahit Kailan','artist':'Carol Banawa','genre':'Pop','image':'https://picsum.photos/seed/KahitKailanCarol/300/300','ytId':'Kahit Kailan Carol Banawa karaoke'},
  {'title':'Wishing You Were Here','artist':'Carol Banawa','genre':'Pop','image':'https://picsum.photos/seed/WishingYouCarol/300/300','ytId':'Wishing You Were Here Carol Banawa karaoke'},
  {'title':'Yakap','artist':'KZ Tandingan','genre':'Pop','image':'https://picsum.photos/seed/YakapKZ/300/300','ytId':'Yakap KZ Tandingan karaoke'},
  {'title':'Versace on the Floor','artist':'KZ Tandingan','genre':'Pop','image':'https://picsum.photos/seed/VersaceKZ/300/300','ytId':'Versace on the Floor KZ Tandingan karaoke'},
  {'title':'Umaasa','artist':'Cueshe','genre':'Pop','image':'https://picsum.photos/seed/UmaasaCueshe/300/300','ytId':'Umaasa Cueshe karaoke'},
  {'title':'Hang On','artist':'Cueshe','genre':'Pop','image':'https://picsum.photos/seed/HangOnCueshe/300/300','ytId':'Hang On Cueshe karaoke'},
  {'title':'Stay','artist':'Cueshe','genre':'Pop','image':'https://picsum.photos/seed/StayCueshe/300/300','ytId':'Stay Cueshe karaoke'},
  {'title':'Here I Am','artist':'Gary Valenciano','genre':'Pop','image':'https://picsum.photos/seed/HereIAmGaryV/300/300','ytId':'Here I Am Gary Valenciano karaoke'},
  {'title':'Kumukutikutitap','artist':'Jose Mari Chan','genre':'Pop','image':'https://picsum.photos/seed/Kumukutikutitap/300/300','ytId':'Kumukutikutitap Jose Mari Chan karaoke'},
  {'title':'Ngayon','artist':'Various','genre':'Pop','image':'https://picsum.photos/seed/NgayonOPMpop/300/300','ytId':'Ngayon OPM pop karaoke'},
  {'title':'Kahit Konting Pagtingin','artist':'Jose Mari Chan','genre':'Pop','image':'https://picsum.photos/seed/KahitKonting/300/300','ytId':'Kahit Konting Pagtingin Jose Mari Chan karaoke'},
  {'title':'Huwag Ka Nang Umiyak','artist':'Various','genre':'Pop','image':'https://picsum.photos/seed/HuwagKaNang/300/300','ytId':'Huwag Ka Nang Umiyak OPM pop karaoke'},
  {'title':'Muntik Na Kitang Minahal','artist':'Gary Valenciano','genre':'Pop','image':'https://picsum.photos/seed/MuntikNaKitang/300/300','ytId':'Muntik Na Kitang Minahal Gary Valenciano karaoke'},
  {'title':'Sana Ay Ikaw Na Nga','artist':'Willie Revillame','genre':'Pop','image':'https://picsum.photos/seed/SanaAyIkaw/300/300','ytId':'Sana Ay Ikaw Na Nga Willie Revillame karaoke'},
  {'title':'Tatlong Beses Sa Isang Linggo','artist':'Various','genre':'Pop','image':'https://picsum.photos/seed/TatlongBeses/300/300','ytId':'Tatlong Beses Sa Isang Linggo OPM karaoke'},
  {'title':'Piliin Mo Ang Pilipinas','artist':'Dulce','genre':'Pop','image':'https://picsum.photos/seed/PiliiinMoAng/300/300','ytId':'Piliin Mo Ang Pilipinas Dulce karaoke'},
  {'title':'Araw-Araw Gabi-Gabi','artist':'Various','genre':'Pop','image':'https://picsum.photos/seed/ArawArawGabi/300/300','ytId':'Araw-Araw Gabi-Gabi OPM pop karaoke'},
  {'title':'Yakap Sa Dilim','artist':'Sam Concepcion','genre':'Pop','image':'https://picsum.photos/seed/YakapSaDilim/300/300','ytId':'Yakap Sa Dilim Sam Concepcion karaoke'},
  {'title':'Number One','artist':'Gary Valenciano','genre':'Pop','image':'https://picsum.photos/seed/NumberOneGaryV/300/300','ytId':'Number One Gary Valenciano karaoke'},
  {'title':'Ikaw at Ako','artist':'Daniel Padilla ft. Kathryn Bernardo','genre':'Pop','image':'https://picsum.photos/seed/IkawAtAkoDaniel/300/300','ytId':'Ikaw At Ako Daniel Padilla karaoke'},
  {'title':'Wag Ka Nang Umiyak','artist':'Erik Santos','genre':'Pop','image':'https://picsum.photos/seed/WagKaNangErik/300/300','ytId':'Wag Ka Nang Umiyak Erik Santos karaoke'},
  {'title':'Naging Sino Ka Ba Sa Akin','artist':'Various','genre':'Pop','image':'https://picsum.photos/seed/NagingSinoKaBa/300/300','ytId':'Naging Sino Ka Ba Sa Akin OPM karaoke'},

  // ── ROCK (90) ─────────────────────────────────────────────────────────────
  {'title':'Narda','artist':'Kamikazee','genre':'Rock','image':'https://i.ytimg.com/vi/L8MzUHxAimI/mqdefault.jpg','ytId':'L8MzUHxAimI'},
  {'title':'Pare Ko','artist':'Eraserheads','genre':'Rock','image':'https://i.ytimg.com/vi/ZeO4kW4j3tI/mqdefault.jpg','ytId':'ZeO4kW4j3tI'},
  {'title':'Mundo','artist':'IV of Spades','genre':'Rock','image':'https://i.ytimg.com/vi/kMKSrRnSV2g/mqdefault.jpg','ytId':'kMKSrRnSV2g'},
  {'title':'Ligaya','artist':'Eraserheads','genre':'Rock','image':'https://picsum.photos/seed/LigayaEheads/300/300','ytId':'Ligaya Eraserheads karaoke'},
  {'title':'Ulan','artist':'Rivermaya','genre':'Rock','image':'https://picsum.photos/seed/UlanRivermaya/300/300','ytId':'Ulan Rivermaya karaoke'},
  {'title':'214','artist':'Rivermaya','genre':'Rock','image':'https://picsum.photos/seed/214Rivermaya/300/300','ytId':'214 Rivermaya karaoke'},
  {'title':'Torete','artist':'Moonstar88','genre':'Rock','image':'https://picsum.photos/seed/ToreteMoonstar88/300/300','ytId':'Torete Moonstar88 karaoke'},
  {'title':'Kisapmata','artist':'Rivermaya','genre':'Rock','image':'https://picsum.photos/seed/KisapmataRivermaya/300/300','ytId':'Kisapmata Rivermaya karaoke'},
  {'title':'Balisong','artist':'Rivermaya','genre':'Rock','image':'https://picsum.photos/seed/BalisongRivermaya/300/300','ytId':'Balisong Rivermaya karaoke'},
  {'title':'Liwanag Sa Dilim','artist':'Rivermaya','genre':'Rock','image':'https://picsum.photos/seed/LiwanagSaDilim/300/300','ytId':'Liwanag Sa Dilim Rivermaya karaoke'},
  {'title':'Awit Ng Kabataan','artist':'Rivermaya','genre':'Rock','image':'https://picsum.photos/seed/AwitNgKabataan/300/300','ytId':'Awit Ng Kabataan Rivermaya karaoke'},
  {'title':'Lagi','artist':'Rivermaya','genre':'Rock','image':'https://picsum.photos/seed/LagiRivermaya/300/300','ytId':'Lagi Rivermaya karaoke'},
  {'title':'Ambisyoso','artist':'Kamikazee','genre':'Rock','image':'https://picsum.photos/seed/AmbisyosoKZ/300/300','ytId':'Ambisyoso Kamikazee karaoke'},
  {'title':'Martyr Ni Bathala','artist':'Kamikazee','genre':'Rock','image':'https://picsum.photos/seed/MartyrNiBathala/300/300','ytId':'Martyr Ni Bathala Kamikazee karaoke'},
  {'title':'Huling Sayaw','artist':'Kamikazee','genre':'Rock','image':'https://picsum.photos/seed/HulingSayaw/300/300','ytId':'Huling Sayaw Kamikazee karaoke'},
  {'title':'Punta Na Tayo Sa Impyerno','artist':'Kamikazee','genre':'Rock','image':'https://picsum.photos/seed/PuntaNaTayo/300/300','ytId':'Punta Na Tayo Sa Impyerno Kamikazee karaoke'},
  {'title':'Hey Barbara','artist':'IV of Spades','genre':'Rock','image':'https://picsum.photos/seed/HeyBarbaraIV/300/300','ytId':'Hey Barbara IV of Spades karaoke'},
  {'title':'Come Inside of My Heart','artist':'IV of Spades','genre':'Rock','image':'https://picsum.photos/seed/ComeInsideOf/300/300','ytId':'Come Inside of My Heart IV of Spades karaoke'},
  {'title':'Htanb','artist':'IV of Spades','genre':'Rock','image':'https://picsum.photos/seed/HtanbIV/300/300','ytId':'HTANB IV of Spades karaoke'},
  {'title':'Noypi','artist':'Bamboo','genre':'Rock','image':'https://picsum.photos/seed/NoypiRock/300/300','ytId':'Noypi Bamboo rock karaoke'},
  {'title':'Tatsulok','artist':'Bamboo','genre':'Rock','image':'https://picsum.photos/seed/TatsulokRock/300/300','ytId':'Tatsulok Bamboo karaoke'},
  {'title':'Mr. Clay','artist':'Bamboo','genre':'Rock','image':'https://picsum.photos/seed/MrClayRock/300/300','ytId':'Mr Clay Bamboo karaoke'},
  {'title':'Storm','artist':'Bamboo','genre':'Rock','image':'https://picsum.photos/seed/StormBamboo/300/300','ytId':'Storm Bamboo karaoke'},
  {'title':'Questions','artist':'Bamboo','genre':'Rock','image':'https://picsum.photos/seed/QuestionsBamboo/300/300','ytId':'Questions Bamboo karaoke'},
  {'title':'Probinsyana','artist':'Bamboo','genre':'Rock','image':'https://picsum.photos/seed/ProbinsyanaBamboo/300/300','ytId':'Probinsyana Bamboo karaoke'},
  {'title':'Huwag Mong Itanong','artist':'Wolfgang','genre':'Rock','image':'https://picsum.photos/seed/HuwagMongItanong/300/300','ytId':'Huwag Mong Itanong Wolfgang karaoke'},
  {'title':'Sana','artist':'Wolfgang','genre':'Rock','image':'https://picsum.photos/seed/SanaWolfgang/300/300','ytId':'Sana Wolfgang karaoke'},
  {'title':'Bakit','artist':'Wolfgang','genre':'Rock','image':'https://picsum.photos/seed/BakitWolfgang/300/300','ytId':'Bakit Wolfgang karaoke'},
  {'title':'The Day You Said Goodnight','artist':'Hale','genre':'Rock','image':'https://picsum.photos/seed/TheDayRock/300/300','ytId':'The Day You Said Goodnight Hale rock karaoke'},
  {'title':'Broken Sonnet','artist':'Hale','genre':'Rock','image':'https://picsum.photos/seed/BrokenSonnetRock/300/300','ytId':'Broken Sonnet Hale rock karaoke'},
  {'title':'Sudapakalayo','artist':'Hale','genre':'Rock','image':'https://picsum.photos/seed/SudapakalayoHale/300/300','ytId':'Sudapakalayo Hale karaoke'},
  {'title':'Halik','artist':'Kamikazee','genre':'Rock','image':'https://picsum.photos/seed/HalikKamikazee/300/300','ytId':'Halik Kamikazee karaoke'},
  {'title':'Tabi Tabi','artist':'Sandwich','genre':'Rock','image':'https://picsum.photos/seed/TabiTabiSandwich/300/300','ytId':'Tabi Tabi Sandwich karaoke'},
  {'title':'Sugal','artist':'Rivermaya','genre':'Rock','image':'https://picsum.photos/seed/SugalRivermaya/300/300','ytId':'Sugal Rivermaya karaoke'},
  {'title':'Araw At Gabi','artist':'Eraserheads','genre':'Rock','image':'https://picsum.photos/seed/ArawAtGabiEH/300/300','ytId':'Araw At Gabi Eraserheads karaoke'},
  {'title':'Shake Yer Head','artist':'Eraserheads','genre':'Rock','image':'https://picsum.photos/seed/ShakeYerHead/300/300','ytId':'Shake Yer Head Eraserheads karaoke'},
  {'title':'Fruitcake','artist':'Eraserheads','genre':'Rock','image':'https://picsum.photos/seed/FruitcakeEH/300/300','ytId':'Fruitcake Eraserheads karaoke'},
  {'title':'Migraine','artist':'Moonstar88','genre':'Rock','image':'https://picsum.photos/seed/MigraineRock/300/300','ytId':'Migraine Moonstar88 rock karaoke'},
  {'title':'Sulat','artist':'Moonstar88','genre':'Rock','image':'https://picsum.photos/seed/SulatRock/300/300','ytId':'Sulat Moonstar88 karaoke'},
  {'title':'Huwag Na Huwag Mong Sasabihin','artist':'Moonstar88','genre':'Rock','image':'https://picsum.photos/seed/HuwagNaRock/300/300','ytId':'Huwag Na Huwag Mong Sasabihin Moonstar88 karaoke'},
  {'title':'Muntik Na','artist':'Cueshe','genre':'Rock','image':'https://picsum.photos/seed/MuntikNaCueshe/300/300','ytId':'Muntik Na Cueshe karaoke'},
  {'title':'Kahit Na','artist':'Cueshe','genre':'Rock','image':'https://picsum.photos/seed/KahitNaCueshe/300/300','ytId':'Kahit Na Cueshe karaoke'},
  {'title':'Kumikitang Kabuhayan','artist':'Eraserheads','genre':'Rock','image':'https://picsum.photos/seed/KumikitangKab/300/300','ytId':'Kumikitang Kabuhayan Eraserheads karaoke'},
  {'title':'Ang Huling El Bimbo','artist':'Eraserheads','genre':'Rock','image':'https://picsum.photos/seed/AngHulingElBimbo/300/300','ytId':'Ang Huling El Bimbo Eraserheads karaoke'},
  {'title':'Bolero','artist':'Eraserheads','genre':'Rock','image':'https://picsum.photos/seed/BoleroEH/300/300','ytId':'Bolero Eraserheads karaoke'},
  {'title':'Torpedo','artist':'Eraserheads','genre':'Rock','image':'https://picsum.photos/seed/TorpedoEH/300/300','ytId':'Torpedo Eraserheads karaoke'},
  {'title':'Kaliwete','artist':'Eraserheads','genre':'Rock','image':'https://picsum.photos/seed/KaliweteEH/300/300','ytId':'Kaliwete Eraserheads karaoke'},
  {'title':'Superproxy','artist':'Eraserheads','genre':'Rock','image':'https://picsum.photos/seed/SuperproxyEH/300/300','ytId':'Superproxy Eraserheads karaoke'},
  {'title':'Iri-Iri','artist':'Eraserheads','genre':'Rock','image':'https://picsum.photos/seed/IriIriEH/300/300','ytId':'Iri-Iri Eraserheads karaoke'},
  {'title':'Magasin','artist':'Eraserheads','genre':'Rock','image':'https://picsum.photos/seed/MagasinRock/300/300','ytId':'Magasin Eraserheads karaoke'},
  {'title':'Umaaraw Umuulan','artist':'Rivermaya','genre':'Rock','image':'https://picsum.photos/seed/UmaarawUmuulan/300/300','ytId':'Umaaraw Umuulan Rivermaya karaoke'},
  {'title':'Noypi','artist':'Rivermaya','genre':'Rock','image':'https://picsum.photos/seed/NoypiRivermaya/300/300','ytId':'Noypi Rivermaya karaoke'},
  {'title':'Rainbow','artist':'Rivermaya','genre':'Rock','image':'https://picsum.photos/seed/RainbowRivermaya/300/300','ytId':'Rainbow Rivermaya karaoke'},
  {'title':'Panahon Na Naman','artist':'Rivermaya','genre':'Rock','image':'https://picsum.photos/seed/PanahonNaNaman/300/300','ytId':'Panahon Na Naman Rivermaya karaoke'},
  {'title':'Hip Hop Hooray','artist':'Rivermaya','genre':'Rock','image':'https://picsum.photos/seed/HipHopHooray/300/300','ytId':'Hip Hop Hooray Rivermaya karaoke'},
  {'title':'Puso','artist':'Rivermaya','genre':'Rock','image':'https://picsum.photos/seed/PusoRivermaya/300/300','ytId':'Puso Rivermaya karaoke'},
  {'title':'Kung Alam Mo Lang','artist':'Rivermaya','genre':'Rock','image':'https://picsum.photos/seed/KungAlamMoRock/300/300','ytId':'Kung Alam Mo Lang Rivermaya karaoke'},
  {'title':'Isang Lahi','artist':'Rivermaya','genre':'Rock','image':'https://picsum.photos/seed/IsangLahi/300/300','ytId':'Isang Lahi Rivermaya karaoke'},
  {'title':'Balisong','artist':'Kamikazee','genre':'Rock','image':'https://picsum.photos/seed/BalisongKZ/300/300','ytId':'Balisong Kamikazee karaoke'},
  {'title':'Tabing Ilog','artist':'Freestyle','genre':'Rock','image':'https://picsum.photos/seed/TabingIlog/300/300','ytId':'Tabing Ilog Freestyle karaoke'},
  {'title':'Alapaap','artist':'Eraserheads','genre':'Rock','image':'https://picsum.photos/seed/AlapaapRock/300/300','ytId':'Alapaap Eraserheads rock karaoke'},
  {'title':'Minsan','artist':'Eraserheads','genre':'Rock','image':'https://picsum.photos/seed/MinsanRock/300/300','ytId':'Minsan Eraserheads karaoke'},
  {'title':'Huwag Mo Na Sana','artist':'Eraserheads','genre':'Rock','image':'https://picsum.photos/seed/HuwagMoNaRock/300/300','ytId':'Huwag Mo Na Sana Eraserheads karaoke'},
  {'title':'Wag Na Wag Mong Sasabihin','artist':'Sugarfree','genre':'Rock','image':'https://picsum.photos/seed/WagNaWagRock/300/300','ytId':'Wag Na Wag Mong Sasabihin Sugarfree rock karaoke'},
  {'title':'Telepono','artist':'Sugarfree','genre':'Rock','image':'https://picsum.photos/seed/TeleponoRock/300/300','ytId':'Telepono Sugarfree karaoke'},
  {'title':'Mariposa','artist':'Sugarfree','genre':'Rock','image':'https://picsum.photos/seed/MariposaRock/300/300','ytId':'Mariposa Sugarfree karaoke'},
  {'title':'Tulog Na','artist':'Sugarfree','genre':'Rock','image':'https://picsum.photos/seed/TulogNaRock/300/300','ytId':'Tulog Na Sugarfree karaoke'},
  {'title':'Silvertoes','artist':'Parokya ni Edgar','genre':'Rock','image':'https://picsum.photos/seed/SilvertoesRock/300/300','ytId':'Silvertoes Parokya ni Edgar karaoke'},
  {'title':'Harana','artist':'Parokya ni Edgar','genre':'Rock','image':'https://picsum.photos/seed/HaranaRock/300/300','ytId':'Harana Parokya ni Edgar karaoke'},
  {'title':'Buloy','artist':'Parokya ni Edgar','genre':'Rock','image':'https://picsum.photos/seed/BuloyRock/300/300','ytId':'Buloy Parokya ni Edgar karaoke'},
  {'title':'Your Pyro','artist':'Parokya ni Edgar','genre':'Rock','image':'https://picsum.photos/seed/YourPyroPNE/300/300','ytId':'Your Pyro Parokya ni Edgar karaoke'},
  {'title':'Bagsakan','artist':'Parokya ni Edgar','genre':'Rock','image':'https://picsum.photos/seed/BagsakanPNE/300/300','ytId':'Bagsakan Parokya ni Edgar karaoke'},
  {'title':'Picha Pie','artist':'Parokya ni Edgar','genre':'Rock','image':'https://picsum.photos/seed/PichaPieRock/300/300','ytId':'Picha Pie Parokya ni Edgar karaoke'},
  {'title':'Tatsulok','artist':'Bamboo','genre':'Rock','image':'https://picsum.photos/seed/TatsulokBambooRock/300/300','ytId':'Tatsulok Bamboo rock karaoke'},
  {'title':'Masaya','artist':'Bamboo','genre':'Rock','image':'https://picsum.photos/seed/MasayaRock/300/300','ytId':'Masaya Bamboo rock karaoke'},
  {'title':'Hallelujah','artist':'Bamboo','genre':'Rock','image':'https://picsum.photos/seed/HallelujahRock/300/300','ytId':'Hallelujah Bamboo rock karaoke'},
  {'title':'Umaasa','artist':'Cueshe','genre':'Rock','image':'https://picsum.photos/seed/UmaasaRock/300/300','ytId':'Umaasa Cueshe rock karaoke'},
  {'title':'Hang On','artist':'Cueshe','genre':'Rock','image':'https://picsum.photos/seed/HangOnRock/300/300','ytId':'Hang On Cueshe rock karaoke'},
  {'title':'Puso','artist':'Wolfgang','genre':'Rock','image':'https://picsum.photos/seed/PusoWolfgang/300/300','ytId':'Puso Wolfgang karaoke'},
  {'title':'Meron Akong Ano','artist':'Parokya ni Edgar','genre':'Rock','image':'https://picsum.photos/seed/MeronAkongAno/300/300','ytId':'Meron Akong Ano Parokya ni Edgar karaoke'},
  {'title':'Pakisabi Na Lang','artist':'Parokya ni Edgar','genre':'Rock','image':'https://picsum.photos/seed/PakisabiNaLang/300/300','ytId':'Pakisabi Na Lang Parokya ni Edgar karaoke'},
  {'title':'Lutang','artist':'AGSUNTA','genre':'Rock','image':'https://picsum.photos/seed/LutangAGSUNTA/300/300','ytId':'Lutang AGSUNTA karaoke'},
  {'title':'Pag-ibig Na Walang Hanggan','artist':'Various','genre':'Rock','image':'https://picsum.photos/seed/PagibigNaWalang/300/300','ytId':'Pag-ibig Na Walang Hanggan rock karaoke'},
  {'title':'Sana Maulit Muli','artist':'Erik Santos','genre':'Rock','image':'https://picsum.photos/seed/SanaMaulitRock/300/300','ytId':'Sana Maulit Muli Erik Santos karaoke'},
  {'title':'Kung Ako Na Lang Sana','artist':'Parokya ni Edgar','genre':'Rock','image':'https://picsum.photos/seed/KungAkoNaLang/300/300','ytId':'Kung Ako Na Lang Sana Parokya ni Edgar karaoke'},
];

// ── Page widget ───────────────────────────────────────────────────────────────

class KaraokeHomePage extends StatefulWidget {
  const KaraokeHomePage({super.key});

  @override
  State<KaraokeHomePage> createState() => _KaraokeHomePageState();
}

class _KaraokeHomePageState extends State<KaraokeHomePage> {
  // ── State ──────────────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedGenre = 'All';
  Set<String> _favTitles = {};

<<<<<<< HEAD
  // ── Preview player ─────────────────────────────────────────────────────────
  final AudioPlayer _previewPlayer = AudioPlayer();
  String _previewingTitle = '';
  bool _previewLoading = false;

  static const _genres = ['All', 'Bisaya', 'OPM', 'Pop', 'Rock', 'Love'];

  static const _pipedInstances = [
    'https://pipedapi.kavin.rocks',
    'https://api.piped.yt',
    'https://piped-api.privacy.com.de',
=======
  static const List<Map<String, String>> _songs = [
    {'title': 'Dadalhin', 'artist': 'Regine Velasquez', 'image': 'https://media.philstar.com/photos/2022/04/19/regine-1_2022-04-19_17-19-51.jpg', 'ytId': 'dv-FqL0KTZE'},
    {'title': 'Ikaw', 'artist': 'Yeng Constantino', 'image': 'https://upload.wikimedia.org/wikipedia/en/b/b4/Yeng_Constantino_-_Ikaw_%28Yeng_Version%29.jpg', 'ytId': 'iOKMTuEhJBc'},
    {'title': 'Kahit Maputi Na Ang Buhok Ko', 'artist': 'Rey Valera', 'image': 'https://i.ytimg.com/vi/UxAX0RjxBeM/maxresdefault.jpg', 'ytId': 'UxAX0RjxBeM'},
    {'title': 'Narda', 'artist': 'Kamikazee', 'image': 'https://i.ytimg.com/vi/L8MzUHxAimI/maxresdefault.jpg', 'ytId': 'L8MzUHxAimI'},
    {'title': 'Hawak Kamay', 'artist': 'Yeng Constantino', 'image': 'https://i.ytimg.com/vi/UxAX0RjxBeM/maxresdefault.jpg', 'ytId': 'tRv7jGEqeqI'},
    {'title': 'Pare Ko', 'artist': 'Eraserheads', 'image': 'https://i.ytimg.com/vi/ZeO4kW4j3tI/maxresdefault.jpg', 'ytId': 'ZeO4kW4j3tI'},
    {'title': 'Pag-ibig', 'artist': 'Kyla', 'image': 'https://i.ytimg.com/vi/UxAX0RjxBeM/maxresdefault.jpg', 'ytId': 'Pag-ibig Kyla karaoke'},
    {'title': 'Magmahal Muli', 'artist': 'Martin Nievera', 'image': 'https://i.ytimg.com/vi/UxAX0RjxBeM/maxresdefault.jpg', 'ytId': 'Magmahal Muli Martin Nievera karaoke'},
    {'title': 'Paalam Muna Sandali', 'artist': 'Darren Espanto', 'image': 'https://tse4.mm.bing.net/th/id/OIP.X4OeqoB_8615vepJpu2zdQHaE7?rs=1&pid=ImgDetMain&o=7&rm=3', 'ytId': 'Paalam Muna Sandali Darren Espanto karaoke'},
    {'title': 'Nasa Iyo Na Ang Lahat', 'artist': 'Daniel Padilla', 'image': 'https://images.genius.com/e817d67292e5c1ac1e72b0c8573161e5.900x900x1.jpg', 'ytId': 'Nasa Iyo Na Ang Lahat Daniel Padilla karaoke'},
    {'title': 'Ulap', 'artist': 'Rob Daniel', 'image': 'https://tse3.mm.bing.net/th/id/OIP.4AnzA3S0-AUEBFjst492KwAAAA?rs=1&pid=ImgDetMain&o=7&rm=3', 'ytId': 'Ulap Rob Daniel karaoke'},
    {'title': 'Fallen', 'artist': 'Lola Amour', 'image': 'https://images.genius.com/b62c08396330faf55dae7e6a73b26324.1000x1000x1.png', 'ytId': 'Fallen Lola Amour karaoke'},
    {'title': 'Binibini', 'artist': 'Arthur Nery', 'image': 'https://i.pinimg.com/736x/c4/51/fd/c451fd1b67b8e80830aaca56188e46d8.jpg', 'ytId': 'Binibini Arthur Nery karaoke'},
    {'title': 'Kumpas', 'artist': 'Moira Dela Torre', 'image': 'https://tse2.mm.bing.net/th/id/OIP.2Uaip4XK2mxVqOEL_zu4cAHaFj?rs=1&pid=ImgDetMain&o=7&rm=3', 'ytId': 'Kumpas Moira Dela Torre karaoke'},
    {'title': 'Randomantic', 'artist': 'James Reid', 'image': 'https://images.genius.com/f428806fd40d83f4a6f934680bdbd7e8.1000x1000x1.jpg', 'ytId': 'Randomantic James Reid karaoke'},
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
  ];

  // ── Sections ───────────────────────────────────────────────────────────────
  List<Map<String, String>> get _visibleSongs {
    var list = _selectedGenre == 'All'
        ? _allSongs
        : _allSongs.where((s) => s['genre'] == _selectedGenre).toList();
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((s) =>
              s['title']!.toLowerCase().contains(q) ||
              s['artist']!.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

<<<<<<< HEAD
  List<Map<String, String>> _byGenre(String genre) =>
      _allSongs.where((s) => s['genre'] == genre).toList();

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
    _loadFavs();
=======
  Set<String> _favTitles = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
    _loadFavs();
  }

  Future<void> _loadFavs() async {
    final list = await FavoritesService.getFavorites();
    if (!mounted) return;
    setState(() => _favTitles = list.map((s) => s['title'] ?? '').toSet());
  }

  Future<void> _toggleFav(Map<String, String> song) async {
    await FavoritesService.toggleFavorite(song);
    await _loadFavs();
    if (!mounted) return;
    final isFav = _favTitles.contains(song['title']);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isFav
          ? '❤️ Added to Favorites'
          : '💔 Removed from Favorites'),
      backgroundColor: AppColors.cardBg,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
    ));
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  // ── Favorites ──────────────────────────────────────────────────────────────
  Future<void> _loadFavs() async {
    final list = await FavoritesService.getFavorites();
    if (!mounted) return;
    setState(() => _favTitles = list.map((s) => s['title'] ?? '').toSet());
  }

  Future<void> _toggleFav(Map<String, String> song) async {
    await FavoritesService.toggleFavorite(song);
    await _loadFavs();
    if (!mounted) return;
    final isFav = _favTitles.contains(song['title']);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isFav ? '❤️ Added to Favorites' : '💔 Removed from Favorites'),
      backgroundColor: AppColors.cardBg,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
    ));
  }

  // ── Piped audio ────────────────────────────────────────────────────────────
  Future<String?> _fetchYtAudio(Map<String, String> song) async {
    final query = Uri.encodeComponent('${song['title']} ${song['artist']}');
    for (final base in _pipedInstances) {
      try {
        final searchRes = await http
            .get(Uri.parse('$base/search?q=$query&filter=music_songs'),
                headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 8));
        if (searchRes.statusCode != 200) continue;
        final items = (json.decode(searchRes.body)['items'] as List?) ?? [];
        for (final item in items.take(3)) {
          try {
            final urlStr = item['url']?.toString() ?? '';
            final videoId = Uri.tryParse('https://youtube.com$urlStr')
                    ?.queryParameters['v'] ??
                '';
            if (videoId.isEmpty) continue;
            final streamRes = await http
                .get(Uri.parse('$base/streams/$videoId'),
                    headers: {'Accept': 'application/json'})
                .timeout(const Duration(seconds: 8));
            if (streamRes.statusCode != 200) continue;
            final audioStreams =
                (json.decode(streamRes.body)['audioStreams'] as List?) ?? [];
            if (audioStreams.isEmpty) continue;
            final sorted = List.from(audioStreams)
              ..sort((a, b) => (b['bitrate'] as int? ?? 0)
                  .compareTo(a['bitrate'] as int? ?? 0));
            final url = sorted.first['url']?.toString();
            if (url != null && url.isNotEmpty) return url;
          } catch (_) {
            continue;
          }
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  // ── iTunes preview (free, no key, CORS-safe on web) ───────────────────────
  Future<String?> _fetchItunesAudio(Map<String, String> song) async {
    try {
      final q = Uri.encodeComponent('${song['title']} ${song['artist']}');
      final res = await http.get(
        Uri.parse(
            'https://itunes.apple.com/search?term=$q&media=music&limit=10&country=PH'),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = json.decode(res.body) as Map<String, dynamic>;
      final results = data['results'] as List?;
      if (results == null || results.isEmpty) return null;
      for (final track in results) {
        final preview = track['previewUrl'] as String?;
        if (preview != null && preview.isNotEmpty) return preview;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _togglePreview(Map<String, String> song) async {
    final title = song['title']!;
    if (_previewingTitle == title) {
      await _previewPlayer.stop();
      setState(() { _previewingTitle = ''; _previewLoading = false; });
      return;
    }
    await _previewPlayer.stop();
    setState(() { _previewingTitle = title; _previewLoading = true; });

    // Web: iTunes first (CORS-safe). Android: YouTube → iTunes fallback.
    String? url;
    if (kIsWeb) {
      url = await _fetchItunesAudio(song);
    } else {
      url = await _fetchYtAudio(song);
      url ??= await _fetchItunesAudio(song);
    }

    if (!mounted) return;
    if (url != null) {
      try {
        await _previewPlayer.setUrl(url);
        await _previewPlayer.play();
        setState(() => _previewLoading = false);
        _previewPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed && mounted) {
            setState(() => _previewingTitle = '');
          }
        });
      } catch (_) {
        if (mounted) setState(() { _previewingTitle = ''; _previewLoading = false; });
      }
    } else {
      if (mounted) {
        setState(() { _previewingTitle = ''; _previewLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⚠️ Preview unavailable for this song'),
          backgroundColor: Colors.black54,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
      }
    }
  }

  void _openKaraoke(Map<String, String> song) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => KaraokeRecordingPage(
        songTitle: song['title']!,
        songArtist: song['artist']!,
        songImage: song['image']!,
        songYtId: song['ytId'] ?? '',
      ),
    ));
  }

  // ── Spotify sheet ──────────────────────────────────────────────────────────
  void _openSpotifySearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SpotifySearchSheet(
        previewPlayer: _previewPlayer,
        onSingTap: (track) {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => KaraokeRecordingPage(
              songTitle: track.title,
              songArtist: track.artist,
              songImage: track.albumArt ?? '',
              songYtId: '${track.title} ${track.artist} karaoke',
            ),
          ));
        },
      ),
    );
  }

  // ── YouTube Music sheet ────────────────────────────────────────────────────
  void _openYtMusicSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _YtMusicSearchSheet(
        previewPlayer: _previewPlayer,
        pipedInstances: _pipedInstances,
        onSingTap: (track) {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => KaraokeRecordingPage(
              songTitle: track.title,
              songArtist: track.artist,
              songImage: track.thumbnail,
              songYtId: track.videoId,
            ),
          ));
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isSearching = _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('Karaoke',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Roboto')),
                  const Spacer(),
                  // YT Music button
                  _HeaderBtn(
                    color: const Color(0xFFFF0000),
                    icon: Icons.queue_music,
                    label: 'YT Music',
                    iconColor: Colors.white,
                    labelColor: Colors.white,
                    onTap: _openYtMusicSearch,
                  ),
                  const SizedBox(width: 6),
                  // Spotify button
                  _HeaderBtn(
                    color: const Color(0xFF1DB954),
                    icon: Icons.music_note,
                    label: 'Spotify',
                    iconColor: Colors.black,
                    labelColor: Colors.black,
                    onTap: _openSpotifySearch,
                  ),
                ],
              ),
            ),

            // ── Search bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF272727),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Roboto'),
                  decoration: InputDecoration(
                    hintText: 'Search songs, artists…',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // ── Main scrollable body ───────────────────────────────────────
            Expanded(
<<<<<<< HEAD
              child: isSearching
                  ? _buildSearchResults()
                  : _buildHomeSections(),
=======
              child: results.isEmpty
                  ? const Center(
                      child: Text(
                        'No songs found',
                        style: TextStyle(
                          color: AppColors.grey,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final song = results[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => KaraokeRecordingPage(
                                  songTitle: song['title']!,
                                  songArtist: song['artist']!,
                                  songImage: song['image']!,
                                  songYtId: song['ytId'] ?? '',
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.inputBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    song['image']!,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, st) => Container(
                                      width: 52,
                                      height: 52,
                                      color: AppColors.grey.withValues(
                                        alpha: 0.3,
                                      ),
                                      child: const Icon(
                                        Icons.music_note,
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song['title']!,
                                        style: const TextStyle(
                                          color: AppColors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Roboto',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        song['artist']!,
                                        style: TextStyle(
                                          color: AppColors.grey.withValues(
                                            alpha: 0.8,
                                          ),
                                          fontSize: 13,
                                          fontFamily: 'Roboto',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _toggleFav(song),
                                  child: Icon(
                                    _favTitles.contains(song['title'])
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: _favTitles.contains(song['title'])
                                        ? Colors.redAccent
                                        : AppColors.grey,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.mic_none_rounded,
                                  color: AppColors.primaryCyan,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushAndRemoveUntil(context,
                MaterialPageRoute(builder: (_) => const HomePage()), (r) => false);
          } else if (index == 1) {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const LibraryPage()));
          } else if (index == 3) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const EducationModePage()));
          }
        },
      ),
    );
  }

  // ── Search results (list view) ─────────────────────────────────────────────
  Widget _buildSearchResults() {
    final results = _visibleSongs;
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, color: Colors.white24, size: 52),
            const SizedBox(height: 12),
            Text('No results for "$_query"',
                style: const TextStyle(color: Colors.white38, fontFamily: 'Roboto')),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _openYtMusicSearch,
              child: const Text('Search on YouTube Music →',
                  style: TextStyle(
                      color: Color(0xFFFF0000),
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: results.length,
      itemBuilder: (_, i) => _buildListTile(results[i]),
    );
  }

  // ── Home sections (YouTube Music style) ────────────────────────────────────
  Widget _buildHomeSections() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // ── Genre chips ─────────────────────────────────────────────────
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _genres.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final g = _genres[i];
                final selected = _selectedGenre == g;
                return GestureDetector(
                  onTap: () => setState(() => _selectedGenre = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : const Color(0xFF272727),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(g,
                        style: TextStyle(
                            color: selected ? Colors.black : Colors.white70,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                            fontFamily: 'Roboto')),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // ── Trending Now ────────────────────────────────────────────────
          _buildSection('🔥 Trending Karaoke', _allSongs.take(20).toList()),

          // ── Bisaya Hits ─────────────────────────────────────────────────
          _buildSection('🌺 Bisaya Hits', _byGenre('Bisaya')),

          // ── Love Songs ──────────────────────────────────────────────────
          _buildSection('💕 Love Songs', _byGenre('Love')),

          // ── OPM Hits ────────────────────────────────────────────────────
          _buildSection('🎤 OPM Hits', _byGenre('OPM')),

          // ── Pop Hits ────────────────────────────────────────────────────
          _buildSection('🎵 Pop Hits', _byGenre('Pop')),

          // ── Rock Anthems ────────────────────────────────────────────────
          _buildSection('🎸 Rock Anthems', _byGenre('Rock')),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Section: title + horizontal card row ───────────────────────────────────
  Widget _buildSection(String title, List<Map<String, String>> songs) {
    if (songs.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto')),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: songs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _buildCard(songs[i]),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Album card (YouTube Music style) ──────────────────────────────────────
  Widget _buildCard(Map<String, String> song) {
    final title = song['title']!;
    final isPlaying = _previewingTitle == title;
    final isLoading = isPlaying && _previewLoading;
    final isFav = _favTitles.contains(title);

    return GestureDetector(
      onTap: () => _openKaraoke(song),
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album art with overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    song['image']!,
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 150, height: 150,
                      decoration: BoxDecoration(
                        color: const Color(0xFF272727),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.music_note, color: Colors.white24, size: 40),
                    ),
                  ),
                ),

                // Dark overlay at bottom
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                      ),
                    ),
                  ),
                ),

                // Play/pause overlay button
                Positioned(
                  bottom: 6, right: 6,
                  child: GestureDetector(
                    onTap: () => _togglePreview(song),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isPlaying ? AppColors.primaryCyan : Colors.white24,
                          width: 1.5,
                        ),
                      ),
                      child: isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primaryCyan,
                              ),
                            )
                          : Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: isPlaying ? AppColors.primaryCyan : Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),

                // Fav button
                Positioned(
                  top: 6, right: 6,
                  child: GestureDetector(
                    onTap: () => _toggleFav(song),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.redAccent : Colors.white70,
                        size: 16,
                      ),
                    ),
                  ),
                ),

                // Playing indicator badge
                if (isPlaying)
                  Positioned(
                    top: 6, left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryCyan,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('▶ Playing',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Roboto')),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 6),

            // Title
            Text(song['title']!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto')),

            // Artist
            Text(song['artist']!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontFamily: 'Roboto')),
          ],
        ),
      ),
    );
  }

  // ── List tile (for search results) ────────────────────────────────────────
  Widget _buildListTile(Map<String, String> song) {
    final title = song['title']!;
    final isPlaying = _previewingTitle == title;
    final isLoading = isPlaying && _previewLoading;
    final isFav = _favTitles.contains(title);

    return GestureDetector(
      onTap: () => _openKaraoke(song),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPlaying
                ? AppColors.primaryCyan.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                song['image']!,
                width: 52, height: 52, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 52, height: 52,
                  color: const Color(0xFF272727),
                  child: const Icon(Icons.music_note, color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song['title']!,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14,
                          fontWeight: FontWeight.w600, fontFamily: 'Roboto'),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(song['artist']!,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12, fontFamily: 'Roboto'),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // Fav
            GestureDetector(
              onTap: () => _toggleFav(song),
              child: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? Colors.redAccent : Colors.white38,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            // Play
            GestureDetector(
              onTap: () => _togglePreview(song),
              child: isLoading
                  ? const SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryCyan))
                  : Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: isPlaying ? AppColors.primaryCyan : Colors.white38,
                      size: 28),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.mic_none_rounded, color: AppColors.primaryCyan, size: 22),
          ],
        ),
      ),
    );
  }
}

// ── Header button helper ──────────────────────────────────────────────────────

class _HeaderBtn extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color labelColor;
  final VoidCallback onTap;

  const _HeaderBtn({
    required this.color,
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: labelColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto')),
          ],
        ),
      ),
    );
  }
}

// ── Spotify Search Sheet ──────────────────────────────────────────────────────

class _SpotifySearchSheet extends StatefulWidget {
  final AudioPlayer previewPlayer;
  final void Function(SpotifyTrack) onSingTap;
  const _SpotifySearchSheet({required this.previewPlayer, required this.onSingTap});

  @override
  State<_SpotifySearchSheet> createState() => _SpotifySearchSheetState();
}

class _SpotifySearchSheetState extends State<_SpotifySearchSheet> {
  final TextEditingController _ctrl = TextEditingController();
  List<SpotifyTrack> _results = [];
  bool _searching = false;
  String _error = '';
  String _previewingId = '';
  bool _previewLoading = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() { _searching = true; _error = ''; _results = []; });
    final tracks = await spotifyService.searchTracks(q.trim(), limit: 20);
    if (!mounted) return;
    if (tracks.isEmpty) {
      setState(() {
        _searching = false;
        _error = SpotifyConfig.clientId == 'YOUR_SPOTIFY_CLIENT_ID'
            ? '⚠️ Add your Spotify Client ID & Secret in spotify_service.dart'
            : 'No results found for "$q"';
      });
    } else {
      setState(() { _searching = false; _results = tracks; });
    }
  }

  Future<void> _togglePreview(SpotifyTrack track) async {
    if (_previewingId == track.id) {
      await widget.previewPlayer.stop();
      setState(() { _previewingId = ''; _previewLoading = false; });
      return;
    }
    if (track.previewUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ No 30-sec preview available for this track'),
        backgroundColor: Colors.black54, behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ));
      return;
    }
    await widget.previewPlayer.stop();
    setState(() { _previewingId = track.id; _previewLoading = true; });
    try {
      await widget.previewPlayer.setUrl(track.previewUrl!);
      await widget.previewPlayer.play();
      if (mounted) setState(() => _previewLoading = false);
      widget.previewPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && mounted) {
          setState(() => _previewingId = '');
        }
      });
    } catch (_) {
      if (mounted) setState(() { _previewingId = ''; _previewLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildSheet(
      color: const Color(0xFF111111),
      accentColor: const Color(0xFF1DB954),
      icon: Icons.music_note,
      title: 'Spotify Search',
      hintText: 'Search any song on Spotify…',
      previewLabel: '30s preview',
      results: _results.map((t) => _SheetTrack(
        id: t.id, title: t.title, artist: t.artist,
        thumbnail: t.albumArt ?? '',
        subtitle: t.previewUrl != null ? '30s preview ● ${t.durationLabel}' : 'No preview ● ${t.durationLabel}',
        hasPreview: t.previewUrl != null,
        isPreviewing: _previewingId == t.id,
        isLoading: _previewingId == t.id && _previewLoading,
        onPreview: () => _togglePreview(t),
        onSing: () => widget.onSingTap(t),
      )).toList(),
      searching: _searching,
      error: _error,
      ctrl: _ctrl,
      onSearch: _search,
      emptyHint: 'Search any song on Spotify\nand tap Sing for karaoke!',
    );
  }
}

// ── YouTube Music Search Sheet ────────────────────────────────────────────────

class YtMusicTrack {
  final String title, artist, thumbnail, videoId;
  final int durationSec;
  const YtMusicTrack({required this.title, required this.artist,
      required this.thumbnail, required this.videoId, required this.durationSec});
  String get durationLabel {
    final m = (durationSec ~/ 60).toString().padLeft(2, '0');
    final s = (durationSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
  factory YtMusicTrack.fromPiped(Map<String, dynamic> json) {
    final urlStr = json['url']?.toString() ?? '';
    final videoId = Uri.tryParse('https://youtube.com$urlStr')?.queryParameters['v'] ?? '';
    return YtMusicTrack(
      title: json['title']?.toString() ?? 'Unknown',
      artist: json['uploaderName']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString() ?? '',
      videoId: videoId,
      durationSec: (json['duration'] as int?) ?? 0,
    );
  }
}

class _YtMusicSearchSheet extends StatefulWidget {
  final AudioPlayer previewPlayer;
  final List<String> pipedInstances;
  final void Function(YtMusicTrack) onSingTap;
  const _YtMusicSearchSheet({required this.previewPlayer,
      required this.pipedInstances, required this.onSingTap});

  @override
  State<_YtMusicSearchSheet> createState() => _YtMusicSearchSheetState();
}

class _YtMusicSearchSheetState extends State<_YtMusicSearchSheet> {
  final TextEditingController _ctrl = TextEditingController();
  List<YtMusicTrack> _results = [];
  bool _searching = false;
  String _error = '';
  String _previewingId = '';
  bool _previewLoading = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() { _searching = true; _error = ''; _results = []; });
    final query = Uri.encodeComponent(q.trim());
    List<YtMusicTrack> tracks = [];
    for (final base in widget.pipedInstances) {
      try {
        final res = await http.get(
          Uri.parse('$base/search?q=$query&filter=music_songs'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) continue;
        final items = (json.decode(res.body)['items'] as List?) ?? [];
        tracks = items.map((e) => YtMusicTrack.fromPiped(e as Map<String, dynamic>))
            .where((t) => t.videoId.isNotEmpty).toList();
        if (tracks.isNotEmpty) break;
      } catch (_) { continue; }
    }
    if (!mounted) return;
    if (tracks.isEmpty) {
      setState(() { _searching = false; _error = 'No results for "$q"'; });
    } else {
      setState(() { _searching = false; _results = tracks; });
    }
  }

  Future<String?> _getStreamUrl(String videoId) async {
    for (final base in widget.pipedInstances) {
      try {
        final res = await http.get(Uri.parse('$base/streams/$videoId'),
            headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) continue;
        final audioStreams = (json.decode(res.body)['audioStreams'] as List?) ?? [];
        if (audioStreams.isEmpty) continue;
        final sorted = List.from(audioStreams)
          ..sort((a, b) => (b['bitrate'] as int? ?? 0).compareTo(a['bitrate'] as int? ?? 0));
        final url = sorted.first['url']?.toString();
        if (url != null && url.isNotEmpty) return url;
      } catch (_) { continue; }
    }
    return null;
  }

  Future<void> _togglePreview(YtMusicTrack track) async {
    if (_previewingId == track.videoId) {
      await widget.previewPlayer.stop();
      setState(() { _previewingId = ''; _previewLoading = false; });
      return;
    }
    await widget.previewPlayer.stop();
    setState(() { _previewingId = track.videoId; _previewLoading = true; });
    final url = await _getStreamUrl(track.videoId);
    if (!mounted) return;
    if (url != null) {
      try {
        await widget.previewPlayer.setUrl(url);
        await widget.previewPlayer.play();
        if (mounted) setState(() => _previewLoading = false);
        widget.previewPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed && mounted) {
            setState(() => _previewingId = '');
          }
        });
      } catch (_) {
        if (mounted) setState(() { _previewingId = ''; _previewLoading = false; });
      }
    } else {
      if (mounted) {
        setState(() { _previewingId = ''; _previewLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⚠️ Could not load stream'),
          backgroundColor: Colors.black54, behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildSheet(
      color: const Color(0xFF0F0F0F),
      accentColor: const Color(0xFFFF0000),
      icon: Icons.queue_music,
      title: 'YouTube Music Search',
      hintText: 'Search any song…',
      previewLabel: 'Full song',
      results: _results.map((t) => _SheetTrack(
        id: t.videoId, title: t.title, artist: t.artist,
        thumbnail: t.thumbnail,
        subtitle: '🎵 Full song  ●  ${t.durationLabel}',
        hasPreview: true,
        isPreviewing: _previewingId == t.videoId,
        isLoading: _previewingId == t.videoId && _previewLoading,
        onPreview: () => _togglePreview(t),
        onSing: () => widget.onSingTap(t),
      )).toList(),
      searching: _searching,
      error: _error,
      ctrl: _ctrl,
      onSearch: _search,
      emptyHint: 'Search any song from YouTube Music\nfor FREE — no account needed!',
    );
  }
}

// ── Shared sheet track data ───────────────────────────────────────────────────

class _SheetTrack {
  final String id, title, artist, thumbnail, subtitle;
  final bool hasPreview, isPreviewing, isLoading;
  final VoidCallback onPreview, onSing;
  const _SheetTrack({
    required this.id, required this.title, required this.artist,
    required this.thumbnail, required this.subtitle,
    required this.hasPreview, required this.isPreviewing,
    required this.isLoading, required this.onPreview, required this.onSing,
  });
}

// ── Shared bottom sheet builder ───────────────────────────────────────────────

Widget _buildSheet({
  required Color color,
  required Color accentColor,
  required IconData icon,
  required String title,
  required String hintText,
  required String previewLabel,
  required List<_SheetTrack> results,
  required bool searching,
  required String error,
  required TextEditingController ctrl,
  required void Function(String) onSearch,
  required String emptyHint,
}) {
  return StatefulBuilder(builder: (context, setS) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                child: Icon(icon, color: accentColor == const Color(0xFF1DB954) ? Colors.black : Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Roboto')),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white, fontFamily: 'Roboto'),
              textInputAction: TextInputAction.search,
              onSubmitted: onSearch,
              onChanged: (_) => setS(() {}),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.white38, fontFamily: 'Roboto'),
                filled: true, fillColor: const Color(0xFF1E1E1E),
                prefixIcon: Icon(Icons.search, color: accentColor),
                suffixIcon: ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                        onPressed: () { ctrl.clear(); setS(() {}); })
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: searching ? null : () => onSearch(ctrl.text),
                icon: searching
                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor == const Color(0xFF1DB954) ? Colors.black : Colors.white))
                    : const Icon(Icons.search, size: 18),
                label: Text(searching ? 'Searching…' : 'Search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: accentColor == const Color(0xFF1DB954) ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(error, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontFamily: 'Roboto', fontSize: 13)),
            ),
          if (results.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: results.length,
                itemBuilder: (_, i) {
                  final t = results[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: t.isPreviewing ? accentColor.withValues(alpha: 0.5) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: t.thumbnail.isNotEmpty
                            ? Image.network(t.thumbnail, width: 52, height: 52, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _sheetPlaceholder(accentColor))
                            : _sheetPlaceholder(accentColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Roboto'), overflow: TextOverflow.ellipsis, maxLines: 2),
                        const SizedBox(height: 2),
                        Text(t.artist, style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Roboto'), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(t.subtitle, style: TextStyle(color: accentColor, fontSize: 11, fontFamily: 'Roboto')),
                      ])),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: t.onPreview,
                        child: t.isLoading
                            ? SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor))
                            : Icon(
                                t.isPreviewing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                color: t.hasPreview ? (t.isPreviewing ? accentColor : Colors.white54) : Colors.white12,
                                size: 32),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: t.onSing,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primaryCyan.withValues(alpha: 0.4)),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.mic, color: AppColors.primaryCyan, size: 14),
                            SizedBox(width: 4),
                            Text('Sing', style: TextStyle(color: AppColors.primaryCyan, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Roboto')),
                          ]),
                        ),
                      ),
                    ]),
                  );
                },
              ),
            ),
          if (results.isEmpty && error.isEmpty && !searching)
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: Colors.white12, size: 60),
                  const SizedBox(height: 12),
                  Text(emptyHint, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white38, fontSize: 14, fontFamily: 'Roboto', height: 1.5)),
                  const SizedBox(height: 8),
                  Text('● Tap ▶ to play  ● Tap Sing for karaoke',
                      style: const TextStyle(color: Colors.white24, fontSize: 12, fontFamily: 'Roboto')),
                ]),
              ),
            ),
        ],
      ),
    );
  });
}

Widget _sheetPlaceholder(Color accent) => Container(
  width: 52, height: 52,
  decoration: BoxDecoration(
    color: accent.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Icon(Icons.music_note, color: accent, size: 24),
);
