//
//  ResultListViewController.swift
//  Hurb
//
//  Created by Alexandre Papanis on 08/08/19.
//  Copyright © 2019 Papanis. All rights reserved.
//

import UIKit
import RxSwift
import Lottie

//Enum para definir as seções,
enum TableSection: Int {
    case CincoEstrelas = 0, QuatroEstrelas = 1, TresEstrelas = 2 , DuasEstrelas = 3, UmaEstrela = 4, ZeroEstrelas = 5, Pacotes = 6
}


protocol ResultListDelegate {
    func updateResultList(newPlace: SuggestionViewModel)
}

class ResultListViewController: UIViewController {

    //MARK: - Properties
    fileprivate let resultCell = "resultCell"
    fileprivate let suggestionCell = "suggestionCell"
    fileprivate let disposeBag = DisposeBag()
    
    //O Default Place está como Rio de Janeiro. No desafio não estava claro se o lugar default era Rio de Janeiro ou Búzios. E no exemplo ainda está usando a cidade de Gramado.
    fileprivate var searchText: String = Defines.DEFAULT_PLACE
    fileprivate var resultListViewModel: ResultListViewModel?
    fileprivate var results: [TableSection: [Hotel]] = [:]
    fileprivate var animationView: AnimationView?
    
    //MARK: - IB Outlets
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var animationLoadingView: UIView!
    @IBOutlet weak var noResultsView: UIView!
    @IBOutlet weak var resultsView: UIView!
    @IBOutlet weak var noInternetConnectionView: UIView!
    
    //MARK: - IB Actions
    //Atual
    @IBAction func reconnect(_ sender: UIButton) {
        self.resultListViewModel = ResultListViewModel(place: self.searchText)
        self.loading()
    }
    
    //MARK: - ViewController life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.tableFooterView = UIView(frame: .zero)
        self.navigationItem.title = "Busca: \(searchText)"
        
        self.resultListViewModel = ResultListViewModel(place: self.searchText)
        self.loading()
        
    }
    
    //MARK: - Functions
    fileprivate func loading() {
        
        //verifica se existe conectividade com a internet
        if !Reachability.isConnectedToNetwork(){
            //se não tiver conectividade, exibe mensagem e gera evento no Firebase
            print("Internet Connection not Available!")
            self.loadingView.isHidden = true
            self.noResultsView.isHidden = true
            self.noInternetConnectionView.isHidden = false
            FirebaseAnalyticsHelper.isNotConnectedEventLogger()
        }else{
            //se tiver conectividade, exibir animação de loading e buscar os hoteis
            print("Internet Connection Available!")
            self.loadingView.isHidden = false
            self.noInternetConnectionView.isHidden = true
            
            animationView = AnimationView(name: "aroundTheWorld")
            animationView!.frame = CGRect(x: 0, y: 0, width: animationLoadingView.frame.size.width, height: animationLoadingView.frame.size.height)
            animationView!.contentMode = .scaleAspectFit
            animationView!.loopMode = .loop
            self.animationLoadingView.addSubview(animationView!)
            animationView!.play()
            
            //Quando o app entra em background, a animação é suspensa. Com essa notificação, quando o app for aberto novamente, a animação do loding deve continuar.
            NotificationCenter.default.addObserver(self, selector: #selector(continueAnimation), name: UIApplication.willEnterForegroundNotification, object: nil)
            
            self.setupSearchHotelsViewModelObserver()
        }
    }
    
    @objc func continueAnimation() {
        animationView!.play()
    }
    
    //MARK: - Rx Setup
    fileprivate func setupSearchHotelsViewModelObserver() {
        if Reachability.isConnectedToNetwork(){
            //aqui é iniciado o Observable do resultListViewModel
            self.resultListViewModel?.hotelsObservable
                .subscribe(onNext: { hotels in
                    
                    //organizar a lista de hoteis em suas respectivas categorias
                    self.results[.CincoEstrelas] = hotels.filter({$0.stars == 5})
                    self.results[.QuatroEstrelas] = hotels.filter({$0.stars == 4})
                    self.results[.TresEstrelas] = hotels.filter({$0.stars == 3})
                    self.results[.DuasEstrelas] = hotels.filter({$0.stars == 2})
                    self.results[.UmaEstrela] = hotels.filter({$0.stars == 1})
                    self.results[.ZeroEstrelas] = hotels.filter({$0.stars == 0})
                    self.results[.Pacotes] = hotels.filter({$0.stars == nil})
                    
                    self.tableView.reloadData()
                    
                    //se ainda não tiver vindo resultados, exibe o loading
                    if hotels.count > 0 {
                        self.loadingView.isHidden = true
                    } else {
                        self.loadingView.isHidden = false
                    }
                    
                    //se a lista ainda estiver vazia, exibe a view de sem resultados
                    if self.resultListViewModel?.count == 0 {
                        self.noResultsView.isHidden = false
                    } else {
                        self.noResultsView.isHidden = true
                    }
                })
                .disposed(by: disposeBag)
        } else {
            self.noInternetConnectionView.isHidden = false
            FirebaseAnalyticsHelper.isNotConnectedEventLogger()
        }
    }
    
    //MARK: - Segues
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        //navegação para a tela de Detalhes do Hotel/Pacote
        if segue.identifier == "showDetails" {
            if let vc = segue.destination as? HotelDetailViewController {
                if let hotelViewModel = sender as? HotelViewModel {
                    vc.hotelViewModel = hotelViewModel
                }
            }
        }
        
        //navegação para a tela de Buscar Lugares
        if segue.identifier == "showSearchPlace"{
            if let vc = segue.destination as? SuggestionsViewController {
                vc.resultListDelegate = self
            }
        }
    }
    
}

//MARK: - implementação dos métodos de ResultListDelegate
extension ResultListViewController: ResultListDelegate {
    
    //Atualizar página com novo local escolhido (usado na tela de Buscar Lugares)
    func updateResultList(newPlace: SuggestionViewModel) {
        
        self.loadingView.isHidden = false
        self.animationView?.play()
        
        self.navigationItem.title = "Busca: \(newPlace.name)"
        self.results = [:]
        self.resultListViewModel?.removeAll()
        self.searchText = newPlace.name
        self.resultListViewModel = ResultListViewModel(place: self.searchText)
        self.setupSearchHotelsViewModelObserver()
    }
}

//MARK: - UITableView extension
extension ResultListViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 7 // De 0 a 5 estrelas e Pacotes
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        //Buscar título do Header de acordo com o número de estrelas.
        if let tableSection = TableSection(rawValue: section), let hotelData = results[tableSection] {
            return hotelData.count
        }
        
        return 0
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Defines.LIST_HEADER[section]
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        //se houver conteudo na section, alterar height do header para 25. Senão, retorna 0 (conteúdo vazio).
        if let tableSection = TableSection(rawValue: section), let hotelData = results[tableSection], hotelData.count > 0 {
            return 25
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: resultCell, for: indexPath) as! ResultCell
        
        //pegar a posição geral
        var rowNumber = indexPath.row
        for i in 0..<indexPath.section {
            rowNumber += self.tableView.numberOfRows(inSection: i)
        }
        
        //inicializar viewModel de acordo com a sua posição geral na página de resultados
        _ = resultListViewModel?[rowNumber]
        
        if let tableSection = TableSection(rawValue: indexPath.section), let hotel = results[tableSection]?[indexPath.row] {
            cell.hotel = HotelViewModel(hotel)
        }
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    
        if let tableSection = TableSection(rawValue: indexPath.section), let hotel = results[tableSection]?[indexPath.row] {
            FirebaseAnalyticsHelper.viewHotelDetailsEventLogger(hotelName: hotel.name!)
            performSegue(withIdentifier: "showDetails", sender: HotelViewModel(hotel))
        }
    
    }
    
}

//MARK: - UIScrollView extension
extension ResultListViewController: UISearchControllerDelegate, UISearchBarDelegate {
    
    //Ao clicar no SearchBar, redirecionar para a View SuggestionsViewController
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        self.performSegue(withIdentifier: "showSearchPlace", sender: nil)
        self.searchBar.resignFirstResponder()
        self.dismissKeyboard()
    }
}
