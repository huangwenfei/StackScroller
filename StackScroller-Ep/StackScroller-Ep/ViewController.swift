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
//             .normalCenterScale(configs: .init(
//                scaleStep: 0.2,
//                size: .rect(240),
//                spacing: 10,
//                insets: .zero
//             ))
//            .normal(configs: .init(
//                isFillPage: true, // false, //
//                size: .rect(240),
//                spacing: 20,
//                insets: .init(value: 10)
//            ))
            // .normal(configs: .simpleUnfill)
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
        
    }


}

