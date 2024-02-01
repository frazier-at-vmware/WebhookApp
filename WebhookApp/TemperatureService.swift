import Foundation
import Alamofire


class TemperatureService {
    static let shared = TemperatureService()
    
    

    func fetchTemperatures(forZip zipCode: String, completion: @escaping (Result<[TemperatureRecord], AFError>) -> Void) {
        let urlString = "https://db.blanketbuddy.app/api/v2/tables/mc1rg3em8tzigqr/records?viewId=vwb8k4qgarb7brlt&limit=365&shuffle=0&offset=0"
        let headers: HTTPHeaders = [
            "accept": "application/json",
            "xc-token": "P5IzMC16RC0FJ6G1PYJDD6JYi_CRPtJ23ILa6OFN"
        ]
        
        AF.request(urlString, headers: headers).responseDecodable(of: TemperatureResponse.self) { response in
            print(response)
            switch response.result {
            case .success(let temperatureResponse):
                // Filter or process records as necessary
                completion(.success(temperatureResponse.list))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

struct TemperatureResponse: Decodable {
    let list: [TemperatureRecord]
}
