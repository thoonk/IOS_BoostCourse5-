//
//  DetailViewController.swift
//  iOS_ProjectE
//
//  Created by 김태훈 on 2020/10/02.
//

import UIKit

class DetailViewController: MovieViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView! {
        didSet{
            indicatorViewAnimating(activityIndicatorView, refresher: refresher , isStart: false)
        }
    }
    
    var movie: Movie?
    var movies: Movies?
    var movieImage: UIImage?
    var comments: [Comment?] = []
    var refresher = UIRefreshControl()
    private lazy var cellImageViewTapGesture: UITapGestureRecognizer = {
        return UITapGestureRecognizer(target: self, action: #selector(cellImageViewTapped))
    }()
    private lazy var wholeSizeImageView: UIImageView = {
        let frame = CGRect(x: 0, y: 44, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height - 88)
        let imageView = UIImageView(frame: frame)
        imageView.contentMode = .scaleToFill
        imageView.isUserInteractionEnabled = true
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(wholeSizeImageViewTapped))
        imageView.addGestureRecognizer(tapGestureRecognizer)
        return imageView
    }()

    struct TableViewSection{
        static let info = 0
        static let synopsis = 1
        static let directorActor = 2
        static let comment = 3
    }
    struct CellIdentifier{
        static let infoCell = "infoCell"
        static let synopsisCell = "synopsisCell"
        static let directorActorCell = "directorActorCell"
        static let commentCell = "commentCell"
        static let headerCell = "headerCell"
    }
    struct SegueIdentifier {
        static let toWriteFromDetail = "toWriteFromDetail"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        requestMovie()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = self.movies?.title
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == SegueIdentifier.toWriteFromDetail{
            guard let writeCommentVC = segue.destination as? WriteCommentViewController,
                  let movie = sender as? Movie else {
                return
            }
            writeCommentVC.movie = movie
        }
    }
    
    // 한줄평 작성 이미지 누를 경우
    @objc private func composeButtonAction(){
        guard let movie: Movie = self.movie else{
            return
        }
        performSegue(withIdentifier: SegueIdentifier.toWriteFromDetail, sender: movie)
    }
    
    // cell의 ImageView 탭할 경우
    @objc private func cellImageViewTapped(){
        for subView in view.subviews{
            subView.isHidden = true
        }
        view.addSubview(wholeSizeImageView)
    }
    
    // 전체 사이즈의 이미지 탭할 경우
    @objc private func wholeSizeImageViewTapped(){
        wholeSizeImageView.removeFromSuperview()
        for subView in view.subviews{
            if subView === activityIndicatorView{
                continue
            }
            subView.isHidden = false
        }

    }
    
    // 영화 데이터 요청
    private func requestMovie(){
        guard let movies: Movies = self.movies else{
            return
        }
        indicatorViewAnimating(self.activityIndicatorView, isStart: true)
        
        let dispatchGroup = DispatchGroup()
        var errorOccurred = false
        
        dispatchGroup.enter()
        request.requestMovieDetail(movies.id){ [weak self] (isSuccess, data, error) in
            guard let self = self else {return}
            if let error = error{
                self.errorHandler(error){
                    self.indicatorViewAnimating(self.activityIndicatorView, refresher: self.refresher, isStart: false)
                }
            }
            if isSuccess {
                guard let movie = data as? Movie else{
                    return
                }
                
                self.movie = movie
  
            }else {
                errorOccurred = true
            }
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        request.requestMovieComments(movies.id){ [weak self] (isSuccess, data, error) in
            guard let self = self  else {return}
            if let error = error{
                self.errorHandler(error){
                    self.indicatorViewAnimating(self.activityIndicatorView, refresher: self.refresher, isStart: false)
                }
            }
            if isSuccess{
                guard let comments = data as? [Comment] else {
                    return
                }
                
                self.comments = comments

            }else {
                errorOccurred = true
            }
            dispatchGroup.leave()
        }
        dispatchGroup.notify(queue: .global()){
            if errorOccurred {
                self.errorHandler(){
                    self.indicatorViewAnimating(self.activityIndicatorView, isStart: false)
                }
            } else {
                self.downloadImage()
            }
        }
    }
    
    private func downloadImage(){
        guard let movie: Movie = self.movie else{
            return
        }
        
        guard let imageURL: URL = URL(string: movie.image) else {
            print("url error")
            return
            
        }
        // ATS로 인하여 http인 경우 Info.plist에서 ATS비활성화해야 함
        guard let imageData: Data = try? Data(contentsOf: imageURL) else {
            print("data error")
            return
        }
        
        guard let image: UIImage = UIImage(data: imageData) else{
            self.errorHandler(){
                self.tableView.isHidden = false
                self.tableView.reloadData()
            }
            return
        }
        movieImage = image
        self.indicatorViewAnimating(self.activityIndicatorView, isStart: false)

        DispatchQueue.main.async {
            self.tableView.isHidden = false
            self.tableView.reloadData()
        }
    }
    
    // MARK: - tableView
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == TableViewSection.comment ? comments.count : 1
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        if indexPath.section == TableViewSection.info {
            return 280
        } else if indexPath.section == TableViewSection.comment {
            return 100
        } else{
            return UITableView.automaticDimension
        }
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == TableViewSection.info ? CGFloat.leastNormalMagnitude : 50
    }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let movie = movie else{
            return UITableViewCell()
        }
        switch indexPath.section{
        // 영화 정보
        case TableViewSection.info:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifier.infoCell, for: indexPath) as? InfoTableViewCell else {
                return UITableViewCell()
                
            }
            cell.mappingData(movie)
            setGradeImageView(cell.gradeImageView, grade: movie.grade)

            if let image = movieImage {
                DispatchQueue.main.async {
                    cell.thumbImageView.image = image
                }
                cell.thumbImageView.addGestureRecognizer(cellImageViewTapGesture)
                wholeSizeImageView.image = image
            }
            return cell
        // 줄거리
        case TableViewSection.synopsis:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifier.synopsisCell, for: indexPath) as? SynopsisTableViewCell else {
                return UITableViewCell()
            }
            
            cell.synopsisLabel.text = movie.synopsis
            return cell
        // 감독/연출
        case TableViewSection.directorActor:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifier.directorActorCell, for: indexPath) as? DirectorActorTableViewCell else{
                return UITableViewCell()
            }
            
            cell.directorLabel.text = movie.director
            cell.actorLabel.text = movie.actor
            
            return cell
        // 한줄평
        case TableViewSection.comment:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifier.commentCell, for: indexPath) as? CommentTableViewCell, let comment = self.comments[indexPath.row] else{
                print("no commentCell")
                return UITableViewCell()
            }
            
            cell.mappingData(comment)
            
            return cell
            
        default:
            return UITableViewCell()
        }
    }
    // 각 cell의 헤더 설정
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 50))
        let label = UILabel(frame: CGRect(x: 10, y: 0, width: 200, height: 50))
        let button = UIButton(frame: CGRect(x: tableView.frame.size.width - 30, y: 20, width: 20, height: 20))
        
        switch section{
        case TableViewSection.synopsis:
            label.text = "줄거리"
            button.isHidden = true
        case TableViewSection.directorActor:
            label.text = "감독/출연"
            button.isHidden = true
        case TableViewSection.comment:
            label.text = "한줄평"
            button.setImage(UIImage(named: "btn_compose"), for: .normal)
            button.isHidden = false
            button.addTarget(self, action: #selector(composeButtonAction), for: .touchUpInside)
        
        default:
            return nil
        }
        view.addSubview(label)
        view.addSubview(button)
        
        return view
    }
}
