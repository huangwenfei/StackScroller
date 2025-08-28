//
//  StackNormalView.swift
//  Xiaosuimian
//
//  Created by windy on 2025/7/31.
//

import UIKit
import Yang

open class StackNormalView<Content>: UIView, UIScrollViewDelegate, StackScrollViewProtocol
    where Content: StackScrollContent
{
    
    // MARK: Type
    public typealias Content = Content
    public typealias Configuration = StackNormalViewConfiguration
    
    // MARK: Properties - Base
    open var oldCurrentPage: Int = 0
    open var currentPage: Int = 0 {
        didSet { oldCurrentPage = oldValue }
    }
    
    open var count: Int = 0
    open private(set) var configuration: Configuration
    
    open var pageChange: PageChangeClosure
    
    open private(set) var visiableItems: [Content] = [] // 无序
    open private(set) var reuseableItems: [Content] = [] // 无序
    
    // MARK: Properties - View
    private lazy var container: UIScrollView = {
        let view = UIScrollView()
        view.backgroundColor = .clear
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.alwaysBounceHorizontal = true
        view.delegate = self
        return view
    }()
    
    // MARK: Properties - Scroll
    open var beginScroll: StackBeginScrollClosure? = nil
    open var changeScroll: StackChangeScrollClosure? = nil
    open var endScroll: StackEndScrollClosure? = nil
    
    // MARK: Init
    public convenience init() {
        self.init(frame: .zero, currentPage: 0, count: 0, configuration: .init())
    }
    
    public init(
        frame: CGRect = .zero,
        currentPage: Int = 0,
        count: Int,
        configuration: Configuration,
        pageChange: @escaping PageChangeClosure = { _,_ in }
    ) {
        self.oldCurrentPage = currentPage
        self.currentPage = currentPage
        self.count = count
        self.pageChange = pageChange
        self.configuration = configuration
        super.init(frame: frame)
        commit()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func commit() {
        addSubview(container)
        addScrollObservers()
    }
    
    deinit {
        removeScrollObservers()
        pageChange = { _,_ in }
        visiableItems = []
        reuseableItems = []
    }
    
    // MARK: Layout
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        let spacing = configuration.spacing
        container.frame = .init(
            origin: .init(x: -spacing * 0.5, y: 0),
            size: .init(width: bounds.width + spacing, height: bounds.height)
        )
        adjustContentSize(by: count)
        layoutElements(by: currentPage)
    }
    
    open func adjustContentSize(by count: Int) {
        
        let itemFrame = self.itemFrame(at: 0)
        container.contentSize = .init(
            width: itemFrame.minX + (itemFrame.width + configuration.spacing) * .init(count),
            height: bounds.height
        )
        
    }
    
    // MARK: Scroll Observer
    private func addScrollObservers() {
        
        container.panGestureRecognizer.addObserver(
            self,
            forKeyPath: #keyPath(UIPanGestureRecognizer.state),
            options: [.new],
            context: nil
        )
        
    }
    
    private func removeScrollObservers() {
        
        container.panGestureRecognizer.removeObserver(
            self,
            forKeyPath: #keyPath(UIPanGestureRecognizer.state)
        )
        
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if
            keyPath == #keyPath(UIPanGestureRecognizer.state),
            let change,
            let new = change[.newKey] as? Int,
            let state = UIPanGestureRecognizer.State(rawValue: new)
        {
            
            switch state {
            case .began:
                beginScroll?(self)
                
            case .changed:
                break
                
            case .ended, .cancelled:
                scrollViewDidScroll(container)
                scrollToCenterPoint(currentPage: currentPage)
                endScroll?(self)
                
            default:
                break
            }
            
        }
        
    }
    
    private func scrollOffset(by page: Int) -> CGPoint {
        
        let width = container.frame.width
        
        let isFillPage = configuration.isFillPage
        let spacing = configuration.spacing
            
        let offset: CGFloat
        if isFillPage {
            offset = (spacing * 0.5) + (width + spacing) * .init(page)
        } else {
            let itemFrame = itemFrame(at: 0)
            let itemWidth = itemFrame.width
            let step = itemWidth + spacing
            offset = step * .init(page) + spacing * 0.5
        }
        
        return .init(x: offset, y: 0)
    }
    
    private func scrollToCenterPoint(currentPage: Int) {
        guard (0 ..< count).contains(currentPage) else { return }
        
        let offset = scrollOffset(by: currentPage)
        
//        print("Center ...", #function, #line, offset, currentPage)
        container.setContentOffset(offset, animated: true)
    
    }
    
    // MARK: UIScrollVeiwDelegate
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        let oldCurrentPage = currentPage
        
        /// - Tag: Page
        let (currentPage, progress) = self.currentPage(
            scrollView: scrollView,
            oldCurrentPage: oldCurrentPage
        )
        self.currentPage = currentPage
        
        changeScroll?(self, progress)
        
        /// - Tag: Layout
        layoutElements(by: currentPage)
        
        /// - Tag: Change
        if oldCurrentPage != currentPage {
            pageChange(oldCurrentPage, currentPage)
        }
        
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        
        guard decelerate else { return }
        
        scrollToCenterPoint(currentPage: currentPage)
        
    }
    
    public func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        
        scrollToCenterPoint(currentPage: currentPage)
        
    }
    
    // MARK: Layout Elements
    
    private func currentPage(scrollView: UIScrollView, oldCurrentPage: Int) -> (page: Int, progress: CGFloat) {
        
        let offset = scrollView.contentOffset.x
        
        func currentPage(framePage: Int, spacing: CGFloat) -> (page: Int, progress: CGFloat) {
            let itemWidth: CGFloat
            if configuration.isFillPage {
                itemWidth = container.frame.width
            } else {
                let itemFrame = itemFrame(at: framePage)
                itemWidth = itemFrame.width
            }
            let step = (itemWidth + spacing)
            let progress = offset / step
            return (Int(round(progress)), progress)
        }
        
        let spacing = configuration.spacing
        let result = currentPage(framePage: 0, spacing: spacing)
        
        return (min(max(result.page, 0), count - 1), min(max(result.progress, 0.0), 1.0))
        
    }
    
    private func visiableRect(currentPage: Int) -> CGRect {
        
        let container = self.container
        let itemFrame = self.itemFrame(at: currentPage)
        
        return CGRect(
            x: itemFrame.minX - (container.frame.width - itemFrame.width) * 0.5,
            y: 0,
            width: container.frame.width,
            height: container.frame.height
        )
        
    }
    
    private func layoutElements(by currentPage: Int) {
        
//        print()
//        print("Before", #function, #line, bounds, currentPage)
        
        guard self.item(for: currentPage) != nil else {
            return
        }
        
        let visiableRect = self.visiableRect(currentPage: currentPage)
        
        clearUnvisiableItems(currentPage: currentPage, in: visiableRect)
        
        /*let edges = */sideItems(
            currentPage: currentPage,
            visiableRect: visiableRect
        )
        
//        print("......", #function, #line, currentPage, visiableRect, centerItem.frame, visiableItems.map({ ($0.page, $0.frame) }))
//        print("After", #function, #line, currentPage, edges, visiableItems.map({ $0.page }))
        
    }
    
    @discardableResult
    private func sideItems(currentPage: Int, visiableRect: CGRect) -> ClosedRange<Int> {
     
        let leftEdge = sideItems(
            currentPage: currentPage, isLeft: true, visiableRect: visiableRect
        )
        let rightEdge = sideItems(
            currentPage: currentPage, isLeft: false, visiableRect: visiableRect
        )
        return leftEdge ... rightEdge
    }
    
    @discardableResult
    private func sideItems(currentPage page: Int, isLeft: Bool, visiableRect: CGRect) -> Int {
        
        var dealingPage = isLeft ? page - 1 : page + 1
        
//                print(#function, #line, isLeft, isLeft ? visiableRect.minX : visiableRect.maxX /* edge */ , currentPage)
        
        while vaildPage(dealingPage) {
            
            let frame = itemFrame(at: dealingPage)
//                    print("---->>>", #function, #line, isLeft, currentPage, item.frame)
            
            if self.isItemContains(frame, isLeft: isLeft, in: visiableRect) {
                item(for: dealingPage)
                dealingPage += isLeft ? -1 : 1
            } else {
                dealingPage -= isLeft ? -1 : 1
                break
            }
            
        }
        
        return dealingPage
    }
    
    private func isItemContains(_ item: Content, isLeft: Bool, in visiableRect: CGRect) -> Bool {
        
        isItemContains(item.frame, isLeft: isLeft, in: visiableRect)
    }
    
    private func isItemNotContains(_ item: Content, isLeft: Bool, in visiableRect: CGRect) -> Bool {
        
        isItemNotContains(item.frame, isLeft: isLeft, in: visiableRect)
    }
    
    private func isItemContains(_ item: CGRect, isLeft: Bool, in visiableRect: CGRect) -> Bool {
        
        let edge = isLeft ? visiableRect.minX : visiableRect.maxX
        let isContains = isLeft ? item.maxX >= edge : item.minX <= edge
        return isContains
    }
    
    private func isItemNotContains(_ item: CGRect, isLeft: Bool, in visiableRect: CGRect) -> Bool {
        
        isItemContains(item, isLeft: isLeft, in: visiableRect) == false
    }
    
    private func clearUnvisiableItems(currentPage: Int, in visiableRect: CGRect) {
        
//        print(#function, #line, currentPage, visiableItems.map({ ($0.page, $0.frame) }))
        
        visiableItems.removeAll(where: { item in
            
            let isLeft = item.page < currentPage
            
            guard
                isItemNotContains(item, isLeft: isLeft, in: visiableRect)
            else {
                return false
            }
            
            itemAnimating(item, isShow: false)
            item.removeFromSuperview()
            item.resetForReuse()
            reuseableItems.append(item)
            
            return true
            
        })
        
//        print(#function, #line, currentPage, visiableItems.map({ ($0.page, $0.frame) }))
        
    }
    
    // MARK: Items
    @discardableResult
    private func item(for page: Int) -> Content? {
        
        guard vaildPage(page) else { return nil }
        
        if let item = visiableItems.first(where: { $0.page == page }) {
            itemAnimatingIfNeed(item, isShow: true)
//            print("====>>", #function, #line, "visiable", page, item.frame)
            return item
        }
        else if let item = reuseableItems.popLast() {
            item.tag = page
            item.frame = itemFrame(at: page)
            item.page = page
            container.addSubview(item)
            visiableItems.append(item)
            item.renderIfNeed()
            itemAnimating(item, isShow: true)
//            print("====>>", #function, #line, "reuseable", page, item.frame)
            return item
        }
        else {
            let item = Content(frame: itemFrame(at: page))
            item.tag = page
            item.page = page
            container.addSubview(item)
            visiableItems.append(item)
            item.renderIfNeed()
            itemAnimating(item, isShow: true)
//            print("====>>", #function, #line, "create", page, item.frame)
            return item
        }
        
    }
    
    private func itemAnimatingIfNeed(_ item: Content, duration: TimeInterval = 0.2, isShow: Bool, completion: ((_ isFinished: Bool) -> Void)? = nil) {
        
        if isShow {
            if item.alpha == 1.0 { return }
        } else {
            if item.alpha == 0.0 { return }
        }
        
        itemAnimating(item, duration: duration, isShow: isShow, completion: completion)
        
    }
    
    private func itemAnimating(_ item: Content, duration: TimeInterval = 0.2, isShow: Bool, completion: ((_ isFinished: Bool) -> Void)? = nil) {
        
        if isShow {
            item.alpha = 0
            UIView.animate(withDuration: duration) {
                item.alpha = 1
            } completion: { isFinished in
                completion?(isFinished)
            }
        } else {
            guard let snap = item.snapshotView(afterScreenUpdates: false) else {
                completion?(true)
                return
            }
            
            snap.frame = item.frame
            snap.alpha = 1
            container.addSubview(snap)
            item.isHidden = true
            
            UIView.animate(withDuration: duration) {
                snap.alpha = 0
            } completion: { isFinished in
                completion?(isFinished)
                snap.removeFromSuperview()
                item.isHidden = false
            }
            
        }
        
    }
    
    private func itemSize(at page: Int) -> CGSize {
        
        let container = self.container
        let boundSize = container.frame.size
        
        let size = configuration.size
        let insets = configuration.insets
            
        let itemSize = size.size(in: boundSize)
        
        let itemWidth = itemSize.width - (insets.horizontal * 2)
        let itemHeight = itemSize.height - (insets.vertical * 2)
        
        return CGSize(width: itemWidth, height: itemHeight)
    }
    
    
    private func itemFrame(at page: Int) -> CGRect {
        
        let container = self.container
        let boundSize = container.frame.size
        let width = boundSize.width
        let height = boundSize.height
        
        let isFillPage = configuration.isFillPage
        let size = configuration.size
        let spacing = configuration.spacing
        let insets = configuration.insets
            
        let page = CGFloat(page)
        let itemSize = size.size(in: boundSize)
        
        let itemWidth = itemSize.width - (insets.horizontal * 2)
        let itemHeight = itemSize.height - (insets.vertical * 2)
        let y = (height - itemHeight) * 0.5
        
        let x: CGFloat
        
        if isFillPage {
            x = (page * (width + spacing)) + ((width - itemWidth) * 0.5) + (spacing * 0.5)
        } else {
            x = (page * (itemWidth + spacing)) + ((width - itemWidth) * 0.5) + (spacing * 0.5)
        }
        
        return CGRect(x: x, y: y, width: itemWidth, height: itemHeight)
    }
    
    // MARK: Scroll
    open func previewPage() {
        scrollToCenterPoint(currentPage: currentPage - 1)
    }
    
    open func nextPage() {
        scrollToCenterPoint(currentPage: currentPage + 1)
    }
    
    open func loopPreviewPage() {
        var page = currentPage - 1
        if page < 0 { page = max(count - 1, 0) }
        scrollToCenterPoint(currentPage: page)
    }
    
    open func loopNextPage() {
        var page = currentPage + 1
        if page >= count { page = 0 }
        scrollToCenterPoint(currentPage: page)
    }
    
    // MARK: Update
    open func update(currentPage: Int) {
        scrollToCenterPoint(currentPage: currentPage)
    }
    
    open func update(count: Int) {
        guard count > 0 else { return }
        self.count = count
        adjustContentSize(by: count)
        if (0 ..< count).contains(currentPage) == false { currentPage = 0 }
        scrollToCenterPoint(currentPage: currentPage)
    }
    
}

public struct StackNormalViewConfiguration: Hashable {
    
    // MARK: Static
    public static let simple: Self = .init()
    public static let simpleUnfill: Self = .init(isFillPage: false)
    
    // MARK: Properties
    public var isFillPage: Bool
    public var size: StackSctollViewSize
    public var spacing: CGFloat
    public var insets: StackScrollViewInsets
    
    // MARK: Init
    public init(
        isFillPage: Bool = true,
        size: StackSctollViewSize = .unspecified,
        spacing: CGFloat = .zero,
        insets: StackScrollViewInsets = .zero
    ) {
        self.isFillPage = isFillPage
        self.size = size
        self.spacing = spacing
        self.insets = insets
    }
    
}
