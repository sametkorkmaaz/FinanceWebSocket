//
//  ViewController.swift
//  FinanceWebSocket
//
//  Created by Samet Korkmaz on 20.06.2025.
//

import UIKit

// Gelen WebSocket mesajını parse etmek için Codable struct'lar
struct WebSocketMessage: Codable {
    let data: [TradeData]?
    let type: String
}

struct TradeData: Codable {
    let s: String // Sembol (Örn: "BINANCE:BTCUSDT")
    let p: Double // Fiyat
}

// Tabloda göstermek için kendi basit modelimiz
struct Currency {
    let symbol: String
    var price: Double
}

class ViewController: UIViewController, UITableViewDataSource {

    // MARK: - IBOutlets
    @IBOutlet weak var tableView: UITableView!

    // MARK: - Properties
    private var webSocketTask: URLSessionWebSocketTask?
    
    // Takip etmek istediğimiz semboller (Finnhub formatında)
    private let symbols = ["BINANCE:BTCUSDT", "OANDA:EUR_USD", "OANDA:GBP_USD", "OANDA:USD_JPY"]
    
    // Tabloyu besleyecek olan veri kaynağımız.
    // Veri geldikçe bu dizi güncellenecek.
    private var currencies = [Currency]() {
        didSet {
            // Veri güncellendiğinde tabloyu ana thread'de yenile
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Başlangıçta tabloyu boş verilerle doldur
        self.currencies = symbols.map { Currency(symbol: $0, price: 0.0) }
        
        // TableView'ın veri kaynağını bu ViewController olarak ayarla
        tableView.dataSource = self
        
        // WebSocket bağlantısını başlat
        connectToWebSocket()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Ekran kapandığında bağlantıyı düzgünce sonlandır
        disconnect()
    }

    // MARK: - WebSocket Methods
    private func connectToWebSocket() {
        // !!! KENDİ API ANAHTARINIZI GİRİN !!!
        let apiKey = "d1ar9hpr01qjhvtqsv1gd1ar9hpr01qjhvtqsv20" // Buraya Finnhub'dan aldığınız anahtarı yapıştırın.
        
        guard let url = URL(string: "wss://ws.finnhub.io?token=\(apiKey)") else {
            print("Hatalı URL")
            return
        }
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume() // Bağlantıyı başlat
        
        print("WebSocket bağlantısı kuruldu.")
        
        subscribeToSymbols()
        listenForMessages()
    }
    
    private func subscribeToSymbols() {
        // Takip etmek istediğimiz her bir sembol için abonelik mesajı gönder
        for symbol in symbols {
            let messageString = "{\"type\":\"subscribe\",\"symbol\":\"\(symbol)\"}"
            let message = URLSessionWebSocketTask.Message.string(messageString)
            
            webSocketTask?.send(message) { error in
                if let error = error {
                    print("Abonelik hatası (\(symbol)): \(error.localizedDescription)")
                } else {
                    print("\(symbol) için abonelik başarılı.")
                }
            }
        }
    }
    
    private func listenForMessages() {
        // Sunucudan gelen mesajları sürekli dinle
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("Mesaj alınırken hata oluştu: \(error.localizedDescription)")
                // Hata durumunda yeniden bağlanmayı deneyebiliriz.
                self?.reconnect()
                
            case .success(let message):
                switch message {
                case .string(let text):
                    // Gelen JSON string'ini işle
                    self?.parseMessage(text)
                case .data(let data):
                    // Gelen data'yı string'e çevirip işle
                    if let text = String(data: data, encoding: .utf8) {
                        self?.parseMessage(text)
                    }
                @unknown default:
                    fatalError()
                }
                
                // Bir sonraki mesajı dinlemek için kendini tekrar çağır
                self?.listenForMessages()
            }
        }
    }
    
    private func parseMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let decodedMessage = try JSONDecoder().decode(WebSocketMessage.self, from: data)
            
            // Eğer mesaj "trade" tipindeyse ve veri içeriyorsa
            if decodedMessage.type == "trade", let trades = decodedMessage.data {
                for trade in trades {
                    // Veri kaynağımızdaki ilgili para birimini bul ve fiyatını güncelle
                    if let index = self.currencies.firstIndex(where: { $0.symbol == trade.s }) {
                        self.currencies[index].price = trade.p
                        // Konsolda anlık fiyatı görmek için
                        // print("Güncellendi: \(self.currencies[index].symbol) -> \(self.currencies[index].price)")
                    }
                }
            }
        } catch {
            // Ping mesajları JSON olmadığı için hata verebilir, bu normaldir.
            // print("JSON parse hatası (muhtemelen ping): \(error)")
        }
    }
    
    private func disconnect() {
        print("WebSocket bağlantısı sonlandırılıyor.")
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }

    private func reconnect() {
        disconnect()
        // 5 saniye sonra tekrar bağlanmayı dene
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            print("Yeniden bağlanılıyor...")
            self.connectToWebSocket()
        }
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currencies.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // "CurrencyCell" identifier'ı ile hücreyi oluştur/yeniden kullan
        let cell = tableView.dequeueReusableCell(withIdentifier: "CurrencyCell", for: indexPath) as! CurrencyCell
        
        // İlgili para birimi verisini al
        let currency = currencies[indexPath.row]
        
        // Hücrenin label'larını güncelle
        cell.symbolLabel.text = currency.symbol
        cell.priceLabel.text = String(format: "%.4f", currency.price) // Fiyatı 4 ondalıklı göster
        
        return cell
    }
}
