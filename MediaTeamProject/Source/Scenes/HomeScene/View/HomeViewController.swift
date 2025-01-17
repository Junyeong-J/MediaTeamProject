//
//  HomeViewController.swift
//  MediaTeamProject
//
//  Created by Joy Kim on 10/9/24.
//

import UIKit
import RxSwift
import RxCocoa
import Kingfisher

final class HomeViewController: BaseViewController<HomeView> {
    
    
    private let viewModel = HomeViewModel()
    private let disposeBag = DisposeBag()
    private let realm = RealmRepository.shared
    
    private var movieTrendList = BehaviorRelay<[Media]>(value: [])
    private var tvTrendList = BehaviorRelay<[Media]>(value: [])
    private let mainPosterMedia = PublishSubject<Media>()
    private let genreResult = PublishSubject<[String]>()
    
    private let viewWillAppearTrigger = PublishSubject<Void>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
        setupNavigationBar()
        setupLikeButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewWillAppearTrigger.onNext(())
    }
}

extension HomeViewController {
    private func setupNavigationBar() {
        
        let rightBarItemOne = UIBarButtonItem(image: AppIcon.sparklesTV, style: .plain, target: nil, action: nil)
        let rightBarItemTwo = UIBarButtonItem(image: AppIcon.magnifyingGlass, style: .plain, target: nil, action: nil)
        let leftBarItem = UIBarButtonItem(image: AppIcon.netflixLogo, style: .plain, target: nil, action: nil)
        navigationItem.rightBarButtonItems = [rightBarItemTwo, rightBarItemOne]
        navigationItem.leftBarButtonItem = leftBarItem
    }
    
    private func bindViewModel() {
        let input = HomeViewModel.Input(viewWillAppear: viewWillAppearTrigger, mainPosterMedia: mainPosterMedia)
        let output = viewModel.transform(input: input)
        
        output.movieTrendList
            .subscribe(onNext: { [weak self] result in
                switch result {
                case .success(let media):
                    let list = media.results
                    self?.movieTrendList.accept(list)
                case .failure(let error):
                    print("movieList 바인딩 실패: \(error)")
                }
            })
            .disposed(by: disposeBag)
        
        output.tvTrendList
            .subscribe(onNext: { [weak self] result in
                switch result {
                case .success(let media):
                    let list = media.results
                    self?.tvTrendList.accept(list)
                case .failure(let error):
                    print("tvList 바인딩 실패: \(error)")
                }
            })
            .disposed(by: disposeBag)
        
        output.genreResult
            .subscribe(onNext: { [weak self] genreNames in
                self?.rootView.genreLabel.text = genreNames.isEmpty ? "장르 정보 없음" : genreNames.joined(separator: ", ")
            })
            .disposed(by: disposeBag)
        
        output.randomMedia
            .subscribe(onNext: { [weak self] media in
                guard let self = self else { return }
                if let media = media {
                    self.mainPosterMedia.onNext(media)
                } else {

                }
                
            })
            .disposed(by: disposeBag)
        
        mainPosterMedia
            .bind(with: self) { owner, media in
                guard let posterpath = media.poster_path else {return}
                let url = APIURL.makeTMDBImageURL(path: posterpath)
                owner.rootView.posterImageView.kf.setImage(with: url)
                owner.rootView.posterImageView.contentMode = .scaleAspectFill
            }
            .disposed(by: disposeBag)
        
        movieTrendList
            .map { Array($0.prefix(10)) }
            .bind(to: rootView.movieCollectionView.rx.items(cellIdentifier: MediaPosterCell.identifier, cellType: MediaPosterCell.self)) {
                item, element, cell in
                cell.configUI(data: element)
            }
            .disposed(by: disposeBag)
        
        tvTrendList
            .map { Array($0.prefix(10)) }
            .bind(to: rootView.tvCollectionView.rx.items(cellIdentifier: MediaPosterCell.identifier, cellType: MediaPosterCell.self)) {
                item, element, cell in
                cell.configUI(data: element)
                cell.clipsToBounds =  true
                cell.layer.cornerRadius = 10
            }
            .disposed(by: disposeBag)
        
        rootView.movieCollectionView.rx.modelSelected(Media.self)
                   .bind(with: self) { owner, media in
                       let detailVC = DetailViewController(viewModel: DetailViewModel(media: media))
                       owner.present(detailVC, animated: true)
                   }
                   .disposed(by: disposeBag)
               
        
               rootView.tvCollectionView.rx.modelSelected(Media.self)
                   .bind(with: self) { owner, media in
                       let detailVC = DetailViewController(viewModel: DetailViewModel(media: media))
                       owner.present(detailVC, animated: true)
                   }
                   .disposed(by: disposeBag)
    }
    
    
    private func setupLikeButton() {
        rootView.likeButton.rx.tap
            .do(onNext: { _ in
            })
            .withLatestFrom(mainPosterMedia)
            .subscribe(onNext: { [weak self] media in
                guard let self = self else {
                    return
                }
                
                if let existingMedia = realm.fetchitem(media.id) {
                    
                    let popupViewModel = PopupMessageViewModel(messageType: .alreadySave)
                    let popupVC = PopupMessageViewController(viewModel: popupViewModel)
                    popupVC.modalPresentationStyle = .overFullScreen
                    self.present(popupVC, animated: true, completion: nil)
                    return
                }
                
                let likedMedia = LikedMedia(
                    id: media.id,
                    backdropPath: media.backdrop_path!,
                    title: media.name ?? media.title ?? "미정",
                    vote_average: media.vote_average,
                    overview: media.overview!,
                    mediaType: media.media_type!,
                    date: Date()
                )
                print(likedMedia)
                rootView.likeButton.isUserInteractionEnabled = true
                RealmRepository.shared.addItem(likedMedia)
                let popupViewModel = PopupMessageViewModel(messageType: .newSave)
                let popupVC = PopupMessageViewController(viewModel: popupViewModel)
                popupVC.modalPresentationStyle = .overFullScreen
                self.present(popupVC, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)
    }
}
