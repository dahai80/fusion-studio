import Foundation
import Combine
import os.log

private let bridgeLog = Logger(subsystem: "com.fusion.studio", category: "FinanceBridge")

class FinanceBridge: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var lastError: String?
    @Published var dashboardResult: FinanceDashboardResult?
    @Published var marketResult: FinanceMarketResult?
    @Published var serviceStatus: FinanceServiceStatus?
    @Published var copilotMessages: [FinanceCopilotMessage] = []

    private let baseURL: String
    private let session: URLSession

    init(baseURL: String = "http://127.0.0.1:8200") {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Health

    func checkHealth() {
        get("/api/v1/") { [weak self] (result: Result<FinanceHealthResponse, Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self?.isConnected = true
                    self?.lastError = nil
                }
            case .failure(let error):
                self?.handleError(error, context: "health")
            }
        }
    }

    // MARK: - Dashboard

    func fetchDashboard(company: String, revenue: [Double], ebitMargin: [Double], wacc: Double = 0.10, terminalGrowth: Double = 0.03, completion: @escaping (Result<FinanceDashboardResult, Error>) -> Void = { _ in }) {
        var body: [String: Any] = [
            "company": company,
            "wacc": wacc,
            "terminal_growth": terminalGrowth
        ]
        if !revenue.isEmpty { body["revenue"] = revenue }
        if !ebitMargin.isEmpty { body["ebit_margin"] = ebitMargin }
        post("/api/v1/dashboard/company", body: body) { [weak self] (result: Result<FinanceDashboardResult, Error>) in
            switch result {
            case .success(let data):
                DispatchQueue.main.async { self?.dashboardResult = data }
                completion(.success(data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchMarketDashboard(preset: String = "quality", limit: Int = 5, completion: @escaping (Result<FinanceMarketResult, Error>) -> Void = { _ in }) {
        let path = "/api/v1/dashboard/market?preset=\(preset)&limit=\(limit)"
        get(path) { [weak self] (result: Result<FinanceMarketResult, Error>) in
            switch result {
            case .success(let data):
                DispatchQueue.main.async { self?.marketResult = data }
                completion(.success(data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchServiceStatus(completion: @escaping (Result<FinanceServiceStatus, Error>) -> Void = { _ in }) {
        get("/api/v1/dashboard/status") { [weak self] (result: Result<FinanceServiceStatus, Error>) in
            switch result {
            case .success(let data):
                DispatchQueue.main.async { self?.serviceStatus = data }
                completion(.success(data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Modeling

    func calculateDCF(company: String, revenue: [Double], wacc: Double = 0.10, terminalGrowth: Double = 0.03, ebitMargin: [Double] = [], netDebt: Double = 0, sharesOutstanding: Double = 0, taxRate: Double = 0.25, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        var body: [String: Any] = [
            "company": company,
            "revenue": revenue,
            "wacc": wacc,
            "terminal_growth": terminalGrowth,
            "net_debt": netDebt,
            "shares_outstanding": sharesOutstanding,
            "tax_rate": taxRate
        ]
        if !ebitMargin.isEmpty { body["ebit_margin"] = ebitMargin }
        postRaw("/api/v1/modeling/dcf/calculate", body: body) { result in
            switch result {
            case .success(let data):
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        completion(.failure(FinanceBridgeError.noData)); return
                    }
                    completion(.success(json))
                } catch {
                    bridgeLog.error("DCF response not JSON object: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func sensitivityAnalysis(company: String, revenue: [Double], wacc: Double = 0.10, terminalGrowth: Double = 0.03, waccRange: [Double] = [], growthRange: [Double] = [], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        var body: [String: Any] = [
            "company": company,
            "revenue": revenue,
            "wacc": wacc,
            "terminal_growth": terminalGrowth
        ]
        if !waccRange.isEmpty { body["wacc_range"] = waccRange }
        if !growthRange.isEmpty { body["growth_range"] = growthRange }
        postRaw("/api/v1/modeling/sensitivity", body: body) { result in
            switch result {
            case .success(let data):
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        completion(.failure(FinanceBridgeError.noData)); return
                    }
                    completion(.success(json))
                } catch {
                    bridgeLog.error("Sensitivity response not JSON object: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func portfolioOptimize(assets: [String], returns: [Double], volatilities: [Double], correlations: [[Double]], riskFree: Double = 0.03, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let body: [String: Any] = [
            "assets": assets,
            "returns": returns,
            "volatilities": volatilities,
            "correlations": correlations,
            "risk_free": riskFree
        ]
        postRaw("/api/v1/modeling/portfolio/optimize", body: body) { result in
            switch result {
            case .success(let data):
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        completion(.failure(FinanceBridgeError.noData)); return
                    }
                    completion(.success(json))
                } catch {
                    bridgeLog.error("Portfolio response not JSON object: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Statements

    func fetchMetrics(incomeStatement: [String: Any], balanceSheet: [String: Any], cashFlow: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let body: [String: Any] = [
            "income_statement": incomeStatement,
            "balance_sheet": balanceSheet,
            "cash_flow": cashFlow
        ]
        postRaw("/api/v1/statements/metrics", body: body) { result in
            switch result {
            case .success(let data):
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        completion(.failure(FinanceBridgeError.noData)); return
                    }
                    completion(.success(json))
                } catch {
                    bridgeLog.error("Metrics response not JSON object: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func screenStocks(filters: [String: Any] = [:], limit: Int = 10, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        var body: [String: Any] = ["limit": limit]
        if !filters.isEmpty { body["filters"] = filters }
        postRaw("/api/v1/statements/screener", body: body) { result in
            switch result {
            case .success(let data):
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        completion(.failure(FinanceBridgeError.noData)); return
                    }
                    completion(.success(json))
                } catch {
                    bridgeLog.error("Screener response not JSON object: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Risk

    func kycScreening(entity: String, country: String = "", industry: String = "", completion: @escaping (Result<[String: Any], Error>) -> Void) {
        var body: [String: Any] = ["entity": entity]
        if !country.isEmpty { body["country"] = country }
        if !industry.isEmpty { body["industry"] = industry }
        postRaw("/api/v1/risk/kyc", body: body) { result in
            switch result {
            case .success(let data):
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        completion(.failure(FinanceBridgeError.noData)); return
                    }
                    completion(.success(json))
                } catch {
                    bridgeLog.error("KYC response not JSON object: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func calculateVar(returns: [Double], portfolioValue: Double = 1000000, confidenceLevels: [Double] = [0.95, 0.99], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let body: [String: Any] = [
            "returns": returns,
            "portfolio_value": portfolioValue,
            "confidence_levels": confidenceLevels
        ]
        postRaw("/api/v1/risk/var", body: body) { result in
            switch result {
            case .success(let data):
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        completion(.failure(FinanceBridgeError.noData)); return
                    }
                    completion(.success(json))
                } catch {
                    bridgeLog.error("VaR response not JSON object: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Report

    func generateValuationReport(company: String, dcfResult: [String: Any] = [:], compsResult: [String: Any] = [:], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        var body: [String: Any] = ["company": company]
        if !dcfResult.isEmpty { body["dcf_result"] = dcfResult }
        if !compsResult.isEmpty { body["comps_result"] = compsResult }
        postRaw("/api/v1/report/valuation", body: body) { result in
            switch result {
            case .success(let data):
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        completion(.failure(FinanceBridgeError.noData)); return
                    }
                    completion(.success(json))
                } catch {
                    bridgeLog.error("Valuation report response not JSON object: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Copilot

    func copilotChat(sessionId: String, message: String, completion: @escaping (Result<FinanceCopilotMessage, Error>) -> Void) {
        let body: [String: Any] = ["message": message, "session_id": sessionId]
        post("/api/v1/copilot/chat", body: body) { [weak self] (result: Result<FinanceCopilotMessage, Error>) in
            switch result {
            case .success(let msg):
                DispatchQueue.main.async { self?.copilotMessages.append(msg) }
                completion(.success(msg))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchCopilotHistory(sessionId: String, completion: @escaping (Result<[FinanceCopilotMessage], Error>) -> Void) {
        get("/api/v1/copilot/history/\(sessionId)") { (result: Result<[FinanceCopilotMessage], Error>) in
            completion(result)
        }
    }

    // MARK: - Generic HTTP

    private func get<T: Decodable>(_ path: String, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(FinanceBridgeError.invalidURL)); return
        }
        session.dataTask(with: url) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(FinanceBridgeError.noData)); return
            }
            guard let data = data else { completion(.failure(FinanceBridgeError.noData)); return }
            guard (200..<300).contains(http.statusCode) else {
                bridgeLog.error("HTTP \(http.statusCode) for GET \(path)")
                completion(.failure(FinanceBridgeError.httpError(http.statusCode))); return
            }
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                bridgeLog.error("Decode failed for \(path): \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any], completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(FinanceBridgeError.invalidURL)); return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error)); return
        }
        session.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(FinanceBridgeError.noData)); return
            }
            guard let data = data else { completion(.failure(FinanceBridgeError.noData)); return }
            guard (200..<300).contains(http.statusCode) else {
                bridgeLog.error("HTTP \(http.statusCode) for POST \(path)")
                completion(.failure(FinanceBridgeError.httpError(http.statusCode))); return
            }
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                bridgeLog.error("Decode failed for POST \(path): \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    private func postRaw(_ path: String, body: [String: Any], completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(FinanceBridgeError.invalidURL)); return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error)); return
        }
        session.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(FinanceBridgeError.noData)); return
            }
            guard let data = data else { completion(.failure(FinanceBridgeError.noData)); return }
            guard (200..<300).contains(http.statusCode) else {
                bridgeLog.error("HTTP \(http.statusCode) for POST \(path)")
                completion(.failure(FinanceBridgeError.httpError(http.statusCode))); return
            }
            completion(.success(data))
        }.resume()
    }

    private func handleError(_ error: Error, context: String) {
        let msg = error.localizedDescription
        bridgeLog.error("FinanceBridge error [\(context)]: \(msg)")
        DispatchQueue.main.async { [weak self] in
            self?.lastError = "\(context): \(msg)"
            if msg.contains("connect") || msg.contains("refused") {
                self?.isConnected = false
            }
        }
    }
}

enum FinanceBridgeError: Error, LocalizedError {
    case invalidURL
    case noData
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .noData: return "No data returned"
        case .httpError(let code): return "HTTP error \(code)"
        }
    }
}
