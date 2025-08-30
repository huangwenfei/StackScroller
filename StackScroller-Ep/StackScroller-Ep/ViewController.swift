//
//  ViewController.swift
//  StackScroller-Ep
//
//  Created by windy on 2025/8/28.
//

import UIKit
import Yang
import StackScroller

class ViewController: UIViewController {
    
    public private(set) lazy var stackCarousel: StackScrollView<StackColorItem> = {
        let view = StackScrollView<StackColorItem>(
            frame: .zero,
            currentPage: 0,
            count: 12, // 6,
            mode:
            .centerScale(configs: .init(
                scaleStep: 0.07,
                offsetStep: 0.25,
                isScaleOffset: false,
                baseline: .bottom,
                size: .rect(150),
                insets: .zero
            ))
        )
        view.setBeginObserver { stack in
            print(#function, #line, "Begin")
        }
        view.setEndObserver { stack in
            print(#function, #line, "End")
        }
        view.backgroundColor = .blue.withAlphaComponent(0.4)
        return view
    }()
    
    lazy var previewPage: UIButton = {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: #selector(previewAction(sender:)), for: .touchUpInside)
        button.setTitle("Preview", for: .normal)
        button.setTitleColor(.yellow, for: .normal)
        button.setTitleColor(.white, for: .highlighted)
        button.backgroundColor = .yellow.withAlphaComponent(0.1)
        return button
    }()
    
    lazy var nextPage: UIButton = {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: #selector(nextAction(sender:)), for: .touchUpInside)
        button.setTitle("Next", for: .normal)
        button.setTitleColor(.green, for: .normal)
        button.setTitleColor(.white, for: .highlighted)
        button.backgroundColor = .green.withAlphaComponent(0.1)
        return button
    }()
    
    lazy var jumpPage: UIButton = {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: #selector(jumpAction(sender:)), for: .touchUpInside)
        button.setTitle("Jump", for: .normal)
        button.setTitleColor(.red, for: .normal)
        button.setTitleColor(.white, for: .highlighted)
        button.backgroundColor = .red.withAlphaComponent(0.1)
        return button
    }()

    lazy var updateSegment: UISegmentedControl = {
        let button = UISegmentedControl(items: ["Normal", "NormalScale", "Stack"])
        button.addTarget(self, action: #selector(updateMode(sender:)), for: .valueChanged)
        button.tintColor = .blue
        button.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.white.withAlphaComponent(0.6)
        ], for: .normal)
        button.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 18),
            .foregroundColor: UIColor.blue
        ], for: .selected)
        button.backgroundColor = .blue.withAlphaComponent(0.2)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        view.backgroundColor = .darkGray
        
        stackCarousel.yang.addToParent(view)
        
        stackCarousel.yangbatch.make { make in
            make.horizontal.equalToParent()
            make.top.equalToParent(.topMargin)
            make.height.equal(to: 260)
        }
        
        jumpPage.yang.addToParent(view)
        
        let jumpHeight = CGFloat(60)
        
        jumpPage.yangbatch.make { make in
            make.height.equal(to: jumpHeight)
            make.horizontal.equalToParent().offsetEdge(16)
            make.center.equalToParent()
        }
        
        previewPage.yang.addToParent(view)
        nextPage.yang.addToParent(view)
        
        previewPage.yangbatch.make { make in
            make.leading.equalToParent().offset(16)
            make.top.equal(to: jumpPage.yangbatch.bottom).offset(16)
            make.height.equal(to: jumpPage)
            make.trailing.equalToParent(.centerX).offset(-4)
        }
        
        nextPage.yangbatch.make { make in
            make.trailing.equalToParent().offsetEdge(16)
            make.top.equal(to: previewPage)
            make.height.equal(to: jumpPage)
            make.leading.equalToParent(.centerX).offset(4)
        }
        
        updateSegment.yang.addToParent(view)
        updateSegment.selectedSegmentIndex = 2
        
        updateSegment.yangbatch.make { make in
            make.horizontal.equal(to: jumpPage)
            make.height.equal(to: jumpPage)
            make.top.equal(to: nextPage.yangbatch.bottom).offset(16)
        }
        
    }
    
    @objc func previewAction(sender: UIButton) {
        stackCarousel.loopPreviewPage()
    }
    
    @objc func nextAction(sender: UIButton) {
        stackCarousel.loopNextPage()
    }
    
    @objc func jumpAction(sender: UIButton) {
        var current = (0 ..< stackCarousel.count).randomElement()!
        if current == stackCarousel.currentPage {
            current = (0 ..< stackCarousel.count).randomElement()!
        }
        print(#function, #line, current)
        stackCarousel.update(currentPage: current)
    }
    
    @objc func updateMode(sender: UISegmentedControl) {
        let mode = StackScrollViewIntMode(rawValue: sender.selectedSegmentIndex)!
        let richMode: StackScrollViewMode
        switch mode {
        case .normal:
            richMode = .normal(configs: .init(
                isFillPage: true, // false,
                size: .rect(240),
                spacing: 20,
                insets: .init(value: 10)
            ))
        case .normalCenterScale:
            richMode = .normalCenterScale(configs: .init(
                scaleStep: 0.2,
                size: .rect(240),
                spacing: 10,
                insets: .zero
            ))
        case .centerScale:
            richMode = .centerScale(configs: .init(
                scaleStep: 0.07,
                offsetStep: 0.25,
                isScaleOffset: false,
                baseline: .bottom,
                size: .rect(150),
                insets: .zero
            ))
        }
        stackCarousel.update(mode: richMode)
    }


}

