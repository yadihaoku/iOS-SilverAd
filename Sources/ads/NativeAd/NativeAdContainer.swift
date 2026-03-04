//
//  NativeAdContainer.swift
//  SceneSample
//
//  Created by yyd on 2026/3/3.
//  Copyright © 2026 Apple. All rights reserved.
//

import UIKit

/// 一个泛型容器，用于包装任意 UIView
class AdContainerView<T: UIView>: UIView {
    
    // 1. 持有内部视图的引用 (类型安全)
    let contentView: T
    
    // 2. 初始化时传入内部视图
    init(contentView: T) {
        self.contentView = contentView
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // 3. 设置子视图和约束
    private func setupView() {
        addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        // 让内部视图填满容器 (也可根据需要修改为 padding)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    // 4. (可选) 重写 hitTest 确保事件能传递给内部视图
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view == self ? contentView : view
    }
}
