# ⚡ ErebusX ⚡





## 🕷️ بالعربية





أداة **ErebusX**  


مشروع مفتوح المصدر لاختبار اختراق شبكات الواي فاي لأغراض تعليمية وأمنية فقط.  





🚨 **تحذير**:  


هذه الأداة مخصصة **للتعلم واختبار الأمان فقط** على شبكتك الخاصة.  


❌ لا يتحمل المطور أو إدارة المشروع أي مسؤولية عن أي استخدام غير قانوني لهذه الأداة.  


✅ الهدف الأساسي هو **التوعية الأمنية** وتحسين حماية شبكاتك.  





---





## 🕷️ In English





**ErebusX** Tool  


An open-source project for Wi-Fi penetration testing for educational and security purposes only.  





🚨 **Disclaimer**:  


This tool is intended **for learning and security testing only** on your own network.  


❌ The developer or project maintainers hold **no responsibility** for any illegal use.  


✅ The main goal is **security awareness** and improving your own network protection.  





---





## 🖼️ صور من الأداة (Screenshots)





### 📌 واجهة المساعدة (Help Menu)


![Help Menu](./assets/Help%20image/Help.png)





### 📌 وضع الهجوم (Attack Mode)


![Attack Mode](./assets/attack%20image/Attack.png)





### 📌 شعار ErebusX (Logo)


![ErebusX Logo](./assets/images/ErebusX.png)





---





## ⚙️ المميزات (Features)





- فحص الشبكات القريبة ومعرفة تفاصيلها (BSSID, Channel, Clients).  


- تشغيل وضع **Monitor Mode** للبطاقة.  


- تنفيذ هجوم **DeAuth** لجمع الـ Handshake.  


- حفظ الـ Handshakes داخل مجلد `handshakes/`.  


- بنر (Banner) ملون ومخصص عند التشغيل ✨.  





---





- Scan nearby Wi-Fi networks and show details (BSSID, Channel, Clients).  


- Enable **Monitor Mode** on wireless interface.  


- Perform **DeAuth Attack** to capture handshakes.  


- Save handshakes inside `handshakes/` folder.  


- Custom colorful banner on startup ✨.  





---





## 📥 التثبيت (Installation)





```bash


git clone https://github.com/YourUserName/ErebusX.git


cd ErebusX/TOOL\ \(ErebusX\)/


chmod +x ErebusX.sh














🚀 الاستخدام (Usage)





sudo ./ErebusX.sh <command> [options]








🛠️ الأوامر المتاحة (Available Commands)


🔹 تحضير الواجهة (Prep)





sudo ./ErebusX.sh prep <iface> <channel>





يضع البطاقة في وضع Monitor ويجهزها للهجوم.


Puts the interface into Monitor Mode and prepares it for attack.








🔹 الفحص (Scan)





sudo ./ErebusX.sh scan <iface> [seconds]





فحص الشبكات القريبة واستخراج CSV مختصر.


Scans nearby networks and exports a summary CSV.








🔹 الهجوم (Attack)





sudo ./ErebusX.sh attack <iface> <ch> <bssid> [all|STA_MAC] [count]











    هجوم DeAuth لجمع Handshake.





    count = عدد الحزم المرسلة (افتراضي 2000).





    Performs DeAuth Attack to capture handshake.





    count = number of packets to send (default 2000).


    


    


    🔹 الاستعادة (Restore)


    


    sudo ./ErebusX.sh restore <iface>





إرجاع البطاقة لوضعها الطبيعي بعد الانتهاء.





Restores the interface back to Managed Mode.














📂 هيكلة المشروع (Project Structure)





ErebusX/


│


├── assets/


│   ├── images/           # صور عامة | General images


│   ├── attack image/     # صور توضيح وضع الهجوم | Attack screenshots


│   └── Help image/       # صور المساعدة | Help screenshots


│


├── TOOL (ErebusX)/


│   └── ErebusX.sh        # السكربت الأساسي | Main script


│


├── LICENSE               # رخصة الاستخدام | License


├── NOTICE                # ملاحظات المشروع | Notice


└── README.md             # ملف التوثيق | Documentation











📜 الرخصة (License)





🇸🇦 بالعربية:





هذا المشروع تحت رخصة Apache-2.0





يمكنك التعديل والاستخدام بحرية، مع الالتزام بشروط الرخصة.





🇬🇧 In English:





This project is licensed under Apache-2.0





You are free to modify and use it, as long as you comply with the license terms.











✨ ErebusX – تعلم الأمن السيبراني، ولكن استخدمه بمسؤولية.





✨ ErebusX – Learn cybersecurity, but use it responsibly.
