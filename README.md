# bpcapture
![](https://github.com/futomtom/bpcapture/raw/master/bpcapture.gif)


只有一個service 0xFFF0 
 收 Characterostic UUID 0xFFF1
 寫 Characterostic UUID 0xFFF2

BLE 名稱: "Bluetooth BP"
1.建立連線後
iphone 送 測量開始封包[0xFD, 0xFD, 0xFA, 0x05, 0x0D, 0x0A]給BLE 

BLE開始測量 持續傳回測量結果[0xFD, 0xFD, 0xFB, 血壓H, 血壓L, 0x0D, 0x0A]給iphone
	壓力值= 血壓H* 256 + 血壓L
一段時間後 傳回最後測量結果值 
[0xFD, 0xFD, 0xFC, 舒張壓, , 收縮壓, 脈搏,0x0D, 0x0A]

  
