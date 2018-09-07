//
//  GalleryViewController.swift
//  BreedFinder
//
//  Created by Sam Hollingsworth on 8/3/18.
//  Copyright © 2018 SJH Studios. All rights reserved.
//
import UIKit
import SwiftyJSON
class GalleryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var tableView: UITableView!
    let session = URLSession.shared
    var imageName: String = ""
    let allBreeds = allDogBreeds()
    var matchedBreeds: [(breed: String, match: String)] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        
        getImage(imageName: imageName)
    }
    
    func getImage(imageName: String){
        let fileManager = FileManager.default
        let imagePath = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString).appendingPathComponent(imageName)
        
        if fileManager.fileExists(atPath: imagePath){
            imageView.image = UIImage(contentsOfFile: imagePath)
            
            findBreed()
            
        }else{
            print("Sorry No Image!")
        }
    }
    
    func findBreed() {
        var googleAPIKey = "*************"
        var googleURL: URL {
            return URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(googleAPIKey)")!
        }
        
        var request = URLRequest(url: googleURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        
        // Build our API request
        let jsonRequest = [
            "requests": [
                "image": [
                    "content": base64EncodeImage(imageView.image!)
                ],
                "features": [
                    [
                        "type": "LABEL_DETECTION",
                        "maxResults": 50
                    ]
                ]
            ]
        ]
        let jsonObject = JSON(jsonRequest)
        
        // Serialize the JSON
        guard let data = try? jsonObject.rawData() else {
            return
        }
        
        request.httpBody = data
        
        let task: URLSessionDataTask = session.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "")
                return
            }
            self.setLabels(data)
        }
        
        task.resume()
        
    }
    
    func setLabels(_ dataToParse: Data) {
        let json = JSON(dataToParse)
        let labels = json["responses"][0]["labelAnnotations"]
        
        for label in labels {
            for breed in allBreeds.allDogBreedsArray {
                // Check if label from Google Vision contains a breed in the description
                if (label.1["description"].stringValue).lowercased().range(of: (breed)) != nil {
                    let breed = ((label.1["description"]).stringValue).capitalized
                    let match = longToShortString(numberStr: (label.1["score"].stringValue))
                    print("\(breed): \(match)")
                    matchedBreeds.append((breed: breed, match: match))
                }
            }
        }
        
        if (matchedBreeds.count == 0) {
            matchedBreeds.append((breed: "Sorry, no matches were found", match: ""))
            matchedBreeds.append((breed: "Try again with a clearer picture", match: ""))
        }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    // Table Functions (3)
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matchedBreeds.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cellReuseIdentifier") as! customTableViewCell
        cell.breedLabel.text = matchedBreeds[indexPath.item].breed
        cell.matchLabel.text = matchedBreeds[indexPath.item].match
        return cell
    }
    
    func longToShortString(numberStr: String) -> String {
        var doublenum = Double(numberStr)!
        doublenum = doublenum * 100 * 100
        doublenum = doublenum.rounded()
        doublenum = doublenum / 100
        return "\(doublenum)%"
    }
    
    func base64EncodeImage(_ image: UIImage) -> String {
        var imagedata = UIImagePNGRepresentation(image)
        
        // Resize the image if it exceeds the 2MB API limit
        if ((imagedata?.count)! > 2097152) {
            let oldSize: CGSize = image.size
            let newSize: CGSize = CGSize(width: 800, height: oldSize.height / oldSize.width * 800)
            imagedata = resizeImage(newSize, image: image)
        }
        
        return imagedata!.base64EncodedString(options: .endLineWithCarriageReturn)
    }
    
    func resizeImage(_ imageSize: CGSize, image: UIImage) -> Data {
        UIGraphicsBeginImageContext(imageSize)
        image.draw(in: CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        let resizedImage = UIImagePNGRepresentation(newImage!)
        UIGraphicsEndImageContext()
        return resizedImage!
    }
    
}
