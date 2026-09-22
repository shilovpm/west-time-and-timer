#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Author the project's String Catalog; no network services are used."""
import json
from pathlib import Path
languages = ['en','zh-Hans','hi','es','ar','fr','bn','pt','id','ur','ru']
# Each row: English key | Chinese | Hindi | Spanish | Arabic | French | Bengali | Portuguese | Indonesian | Urdu | Russian.
rows = '''Timer|计时器|टाइमर|Temporizador|المؤقت|Minuteur|টাইমার|Temporizador|Pengatur waktu|ٹائمر|Таймер
World clocks|世界时钟|विश्व घड़ियाँ|Relojes mundiales|الساعات العالمية|Horloges mondiales|বিশ্ব ঘড়ি|Relógios mundiais|Jam dunia|عالمی گھڑیاں|Мировые часы
Settings|设置|सेटिंग|Ajustes|الإعدادات|Réglages|সেটিংস|Definições|Pengaturan|ترتیبات|Настройки
Add clock|添加时钟|घड़ी जोड़ें|Añadir reloj|إضافة ساعة|Ajouter une horloge|ঘড়ি যোগ করুন|Adicionar relógio|Tambah jam|گھڑی شامل کریں|Добавить часы
Add|添加|जोड़ें|Añadir|إضافة|Ajouter|যোগ করুন|Adicionar|Tambah|شامل کریں|Добавить
Cancel|取消|रद्द करें|Cancelar|إلغاء|Annuler|বাতিল|Cancelar|Batal|منسوخ|Отмена
Start|开始|शुरू करें|Iniciar|بدء|Démarrer|শুরু|Iniciar|Mulai|شروع|Старт
Pause|暂停|रोकें|Pausar|إيقاف مؤقت|Pause|বিরতি|Pausar|Jeda|وقفہ|Пауза
Continue|继续|जारी रखें|Continuar|متابعة|Reprendre|চালিয়ে যান|Continuar|Lanjutkan|جاری رکھیں|Продолжить
Reset|重置|रीसेट|Restablecer|إعادة ضبط|Réinitialiser|রিসেট|Repor|Atur ulang|ری سیٹ|Сброс
Repeat|重复|दोहराएँ|Repetir|تكرار|Répéter|পুনরাবৃত্তি|Repetir|Ulangi|دہرائیں|Повтор
Set|设置|सेट करें|Aplicar|تعيين|Appliquer|সেট করুন|Definir|Terapkan|مقرر کریں|Задать
Set duration|设置时长|अवधि सेट करें|Fijar duración|تعيين المدة|Définir la durée|সময় নির্ধারণ|Definir duração|Atur durasi|دورانیہ مقرر کریں|Задать длительность
Timer finished|计时结束|टाइमर समाप्त|Temporizador terminado|انتهى المؤقت|Minuteur terminé|টাইমার শেষ|Temporizador terminado|Waktu habis|ٹائمر ختم|Таймер завершён
Your countdown has finished.|倒计时已结束。|आपकी उलटी गिनती समाप्त हो गई।|La cuenta atrás ha terminado.|انتهى العد التنازلي.|Votre compte à rebours est terminé.|আপনার কাউন্টডাউন শেষ হয়েছে।|A contagem decrescente terminou.|Hitung mundur selesai.|آپ کی الٹی گنتی ختم ہو گئی۔|Обратный отсчёт завершён.
h|小时|घं|h|س|h|ঘণ্টা|h|j|گھنٹے|ч
min|分钟|मि|min|د|min|min|min|mnt|منٹ|мин
s|秒|से|s|ث|s|সে|s|dtk|سیکنڈ|с
Move up|上移|ऊपर करें|Subir|نقل لأعلى|Monter|উপরে নিন|Mover para cima|Naik|اوپر کریں|Выше
Move down|下移|नीचे करें|Bajar|نقل لأسفل|Descendre|নিচে নিন|Mover para baixo|Turun|نیچے کریں|Ниже
Remove clock|删除时钟|घड़ी हटाएँ|Eliminar reloj|حذف الساعة|Supprimer l’horloge|ঘড়ি সরান|Remover relógio|Hapus jam|گھڑی ہٹائیں|Удалить часы
Retry|重试|पुनः प्रयास|Reintentar|إعادة المحاولة|Réessayer|আবার চেষ্টা|Tentar novamente|Coba lagi|دوبارہ کوشش|Повторить попытку
Cities|城市|शहर|Ciudades|المدن|Villes|শহর|Cidades|Kota|شہر|Города
Time zone designations|时区简称|समय क्षेत्र संक्षेप|Abreviaturas horarias|اختصارات المناطق الزمنية|Abréviations des fuseaux|সময় অঞ্চলের সংক্ষিপ্ত নাম|Designações de fusos|Singkatan zona waktu|ٹائم زون کے مخففات|Обозначения поясов
Category|类别|श्रेणी|Categoría|الفئة|Catégorie|বিভাগ|Categoria|Kategori|قسم|Категория
City, country, IANA or abbreviation|城市、国家、IANA 或简称|शहर, देश, IANA या संक्षेप|Ciudad, país, IANA o abreviatura|مدينة أو بلد أو IANA أو اختصار|Ville, pays, IANA ou abréviation|শহর, দেশ, IANA বা সংক্ষিপ্ত নাম|Cidade, país, IANA ou abreviatura|Kota, negara, IANA atau singkatan|شہر، ملک، IANA یا مخفف|Город, страна, IANA или обозначение
Automatic seasonal rules for this region|使用此地区的自动季节规则|इस क्षेत्र के स्वचालित मौसमी नियम|Reglas estacionales automáticas de esta región|القواعد الموسمية التلقائية لهذه المنطقة|Règles saisonnières automatiques de cette région|এই অঞ্চলের স্বয়ংক্রিয় ঋতুভিত্তিক নিয়ম|Regras sazonais automáticas desta região|Aturan musiman otomatis wilayah ini|اس خطے کے خودکار موسمی اصول|Автоматические сезонные правила этого региона
A small offline catalog. UTC offsets filter current seasonal time.|小型离线目录。UTC 偏移量按当前季节时间筛选。|छोटी ऑफ़लाइन सूची। UTC अंतर वर्तमान मौसमी समय को छाँटता है।|Catálogo reducido sin conexión. UTC filtra el horario estacional actual.|دليل صغير دون إنترنت. إزاحات UTC ترشح الوقت الموسمي الحالي.|Petit catalogue hors ligne. Les décalages UTC filtrent l’heure saisonnière actuelle.|ছোট অফলাইন তালিকা। UTC ব্যবধান বর্তমান ঋতুভিত্তিক সময় বেছে নেয়।|Catálogo pequeno offline. UTC filtra a hora sazonal atual.|Katalog kecil luring. Selisih UTC menyaring waktu musiman saat ini.|مختصر آف لائن فہرست۔ UTC فرق موجودہ موسمی وقت کو چھانٹتا ہے۔|Небольшой офлайн-каталог. UTC-смещение фильтрует текущее сезонное время.
Language|语言|भाषा|Idioma|اللغة|Langue|ভাষা|Idioma|Bahasa|زبان|Язык
System|系统|सिस्टम|Sistema|النظام|Système|সিস্টেম|Sistema|Sistem|سسٹم|Системный
Show seconds in clocks|时钟显示秒数|घड़ियों में सेकंड दिखाएँ|Mostrar segundos|إظهار الثواني في الساعات|Afficher les secondes|ঘড়িতে সেকেন্ড দেখান|Mostrar segundos nos relógios|Tampilkan detik pada jam|گھڑیوں میں سیکنڈ دکھائیں|Показывать секунды в часах
Time format|时间格式|समय प्रारूप|Formato horario|تنسيق الوقت|Format de l’heure|সময়ের বিন্যাস|Formato da hora|Format waktu|وقت کی شکل|Формат времени
12 hour|12 小时|12 घंटे|12 horas|12 ساعة|12 heures|১২ ঘণ্টা|12 horas|12 jam|12 گھنٹے|12 часов
24 hour|24 小时|24 घंटे|24 horas|24 ساعة|24 heures|২৪ ঘণ্টা|24 horas|24 jam|24 گھنٹے|24 часа
Notifications|通知|सूचनाएँ|Notificaciones|الإشعارات|Notifications|বিজ্ঞপ্তি|Notificações|Notifikasi|اطلاعات|Уведомления
Allowed|已允许|अनुमत|Permitidas|مسموح|Autorisées|অনুমোদিত|Permitidas|Diizinkan|اجازت ہے|Разрешены
Denied|已拒绝|अस्वीकृत|Denegadas|مرفوض|Refusées|অনুমতি নেই|Recusadas|Ditolak|اجازت نہیں|Запрещены
Not requested|尚未请求|अनुरोध नहीं किया|Sin solicitar|لم يُطلب|Non demandées|অনুরোধ করা হয়নি|Não solicitadas|Belum diminta|درخواست نہیں کی گئی|Не запрашивались
Open notification settings|打开通知设置|सूचना सेटिंग खोलें|Abrir ajustes de notificaciones|فتح إعدادات الإشعارات|Ouvrir les réglages des notifications|বিজ্ঞপ্তির সেটিংস খুলুন|Abrir definições de notificações|Buka pengaturan notifikasi|اطلاعات کی ترتیبات کھولیں|Настройки уведомлений
Sleep counts toward the timer. Changing the system clock can change the remaining time.|睡眠时间计入计时。更改系统时间可能改变剩余时间。|नींद का समय गिना जाता है। सिस्टम घड़ी बदलने से शेष समय बदल सकता है।|El reposo cuenta. Cambiar la hora del sistema puede cambiar el tiempo restante.|السكون محسوب. قد يؤدي تغيير ساعة النظام إلى تغيير الوقت المتبقي.|La veille compte. Modifier l’horloge système peut changer le temps restant.|ঘুমের সময় গণনা করা হয়। সিস্টেমের সময় বদলালে অবশিষ্ট সময় বদলাতে পারে।|A suspensão conta. Alterar o relógio do sistema pode alterar o tempo restante.|Tidur dihitung. Mengubah jam sistem dapat mengubah waktu tersisa.|نیند کا وقت شمار ہوتا ہے۔ سسٹم گھڑی بدلنے سے باقی وقت بدل سکتا ہے۔|Сон входит в отсчёт. Коррекция системных часов может изменить остаток.
Removed clock|时钟已删除|घड़ी हटा दी गई|Reloj eliminado|ساعة محذوفة|Horloge supprimée|ঘড়ি সরানো হয়েছে|Relógio removido|Jam dihapus|گھڑی ہٹا دی گئی|Часы удалены
Open app to check saved data|打开应用检查数据|डेटा जाँचने के लिए ऐप खोलें|Abrir app para revisar datos|فتح التطبيق لفحص البيانات|Ouvrir l’app pour vérifier les données|তথ্য পরীক্ষা করতে অ্যাপ খুলুন|Abrir app para verificar dados|Buka aplikasi untuk memeriksa data|ڈیٹا دیکھنے کے لیے ایپ کھولیں|Открыть приложение для проверки данных
Saved clock|已保存的时钟|सहेजी गई घड़ी|Reloj guardado|ساعة محفوظة|Horloge enregistrée|সংরক্ষিত ঘড়ি|Relógio guardado|Jam tersimpan|محفوظ گھڑی|Сохранённые часы
Saved clocks|已保存的时钟|सहेजी गई घड़ियाँ|Relojes guardados|الساعات المحفوظة|Horloges enregistrées|সংরক্ষিত ঘড়ি|Relógios guardados|Jam tersimpan|محفوظ گھڑیاں|Сохранённые часы
Control timer|控制计时器|टाइमर नियंत्रित करें|Controlar temporizador|التحكم بالمؤقت|Contrôler le minuteur|টাইমার নিয়ন্ত্রণ|Controlar temporizador|Kendalikan pengatur waktu|ٹائمر کنٹرول کریں|Управление таймером
Command|命令|आदेश|Comando|الأمر|Commande|নির্দেশ|Comando|Perintah|حکم|Команда
Run|运行|रन|Ejecución|التشغيل|Exécution|চালনা|Execução|Jalankan|اجرا|Запуск
Version|版本|संस्करण|Versión|الإصدار|Version|সংস্করণ|Versão|Versi|ورژن|Версия
Choose saved clocks. Empty selection uses the shared list.|选择已保存的时钟。留空则使用共享列表。|घड़ियाँ चुनें। खाली चयन साझा सूची का उपयोग करता है।|Elige relojes. La selección vacía usa la lista común.|اختر الساعات. الاختيار الفارغ يستخدم القائمة المشتركة.|Choisissez les horloges. Une sélection vide utilise la liste commune.|ঘড়ি বেছে নিন। ফাঁকা থাকলে সাধারণ তালিকা ব্যবহার হবে।|Escolha relógios. A seleção vazia usa a lista comum.|Pilih jam. Pilihan kosong memakai daftar bersama.|گھڑیاں منتخب کریں۔ خالی انتخاب مشترک فہرست استعمال کرتا ہے۔|Выберите часы. Пустой выбор использует общий список.
Control the single shared timer.|控制一个共享计时器。|एक साझा टाइमर नियंत्रित करें।|Controla el único temporizador compartido.|التحكم بالمؤقت المشترك الوحيد.|Contrôlez le minuteur commun.|একটি সাধারণ টাইমার নিয়ন্ত্রণ করুন।|Controle o único temporizador comum.|Kendalikan satu pengatur waktu bersama.|ایک مشترک ٹائمر کنٹرول کریں۔|Управление одним общим таймером.
Your saved cities and seasonal time zones.|已保存的城市和季节时区。|आपके शहर और मौसमी समय क्षेत्र।|Tus ciudades y zonas estacionales.|مدنك ومناطقك الزمنية الموسمية.|Vos villes et fuseaux saisonniers.|আপনার শহর ও ঋতুভিত্তিক সময় অঞ্চল।|As suas cidades e fusos sazonais.|Kota dan zona musiman tersimpan.|آپ کے محفوظ شہر اور موسمی ٹائم زون۔|Ваши города и сезонные пояса.
One shared countdown.|一个共享倒计时。|एक साझा उलटी गिनती।|Una cuenta atrás compartida.|عد تنازلي مشترك واحد.|Un compte à rebours commun.|একটি সাধারণ কাউন্টডাউন।|Uma contagem decrescente comum.|Satu hitung mundur bersama.|ایک مشترک الٹی گنتی۔|Один общий отсчёт.'''
strings = {}
for row in rows.splitlines():
    values = row.split('|')
    assert len(values) == len(languages), (values[0], len(values))
    strings[values[0]] = {'extractionState': 'manual', 'localizations': {
        language: {'stringUnit': {'state': 'translated', 'value': value}}
        for language, value in zip(languages, values)}}
path = Path(__file__).resolve().parents[1] / 'WEST/Resources/Localizable.xcstrings'
path.write_text(json.dumps({'sourceLanguage': 'en', 'strings': strings, 'version': '1.0'}, ensure_ascii=False, indent=2) + '\n')
print(f'{len(strings)} keys × {len(languages)} languages')
