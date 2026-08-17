class Store {
    var items: [String] = []
    var prices: [String: Int] = [:]
    let pricingService: any PricingService

    init(pricingService: any PricingService) {
        self.pricingService = pricingService
    }
