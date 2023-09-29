//
//  TableViewController.swift
//  CS7323 Flipped module 2
//
//  Created by Bryce Shurts 9/25/23
//

import UIKit

class TableViewController: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    
        return 1;
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Add in the only cell so that we can navigate to the audio lab
        return tableView.dequeueReusableCell(withIdentifier: "audioLab", for: indexPath)
        
    }
    
}
