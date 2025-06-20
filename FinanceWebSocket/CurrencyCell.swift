//
//  CurrencyCell.swift
//  FinanceWebSocket
//
//  Created by Samet Korkmaz on 20.06.2025.
//

import UIKit

class CurrencyCell: UITableViewCell {

    @IBOutlet weak var priceLabel: UILabel!
    
    @IBOutlet weak var symbolLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
