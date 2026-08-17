class Store {
    var items: [String] = []
    var prices: [String: Int] = [:]
    let pricingService: any PricingService

    init(pricingService: any PricingService) {
        self.pricingService = pricingService
    }

    func register(_ item: String) {
        items.append(item)
        prices[item] = pricingService.price(for: item)
    }
}
