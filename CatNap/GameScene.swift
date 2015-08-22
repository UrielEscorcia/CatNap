//
//  GameScene.swift
//  CatNap
//
//  Created by Uriel Escorcia Cortés on 8/10/15.
//  Copyright (c) 2015 Mimo. All rights reserved.
//

import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    struct PhysicsCategory {
        static let None: UInt32 = 0 //0
        static let Cat: UInt32 = 0b1 //1
        static let Block: UInt32 = 0b10 //2
        static let Bed: UInt32 = 0b100 //4
        static let Edge: UInt32 = 0b1000 //8
        static let Label: UInt32 = 0b10000 //16
        static let Spring: UInt32 = 0b100000 //32
        static let Hook: UInt32 = 0b1000000 //64
    }
 
    var bedNode: SKSpriteNode!
    var catNode: SKSpriteNode!
    var currentLevel: Int = 0
    
    var hookBaseNode: SKSpriteNode!
    var hookNode: SKSpriteNode!
    var hookJoint: SKPhysicsJoint!
    var ropeNode: SKSpriteNode!
    
    class func level(levelNum: Int) -> GameScene? {
        let scene = GameScene(fileNamed: "Level\(levelNum)")
        scene.currentLevel = levelNum
        scene.scaleMode = .AspectFill
        return scene
    }
    
    override func didMoveToView(view: SKView) {
        
        let maxAspectRatio: CGFloat = 16.0 / 9.0
        let maxAspectRatioHeight: CGFloat = size.width / maxAspectRatio
        let playableMargin: CGFloat = (size.height - maxAspectRatioHeight) / 2
        let playableRect = CGRect(x: 0, y: playableMargin, width: size.width, height: size.height - playableMargin*2)
        
        physicsBody = SKPhysicsBody(edgeLoopFromRect: playableRect)
        physicsWorld.contactDelegate = self
        physicsBody!.categoryBitMask = PhysicsCategory.Edge
        
        bedNode = childNodeWithName("bed") as! SKSpriteNode
        catNode = childNodeWithName("cat") as! SKSpriteNode
        
//        bedNode.setScale(1.5)
//        catNode.setScale(1.5)
        
        let bedBodySize = CGSize(width: 40, height: 30)
        bedNode.physicsBody = SKPhysicsBody(rectangleOfSize: bedBodySize)
        bedNode.physicsBody!.dynamic = false
        
        let catBodyTexture = SKTexture(imageNamed: "cat_body")
        catNode.physicsBody = SKPhysicsBody(texture: catBodyTexture, size: catNode.size)
        
        SKTAudio.sharedInstance().playBackgroundMusic("backgroundMusic.mp3")
        
        bedNode.physicsBody!.categoryBitMask = PhysicsCategory.Bed
        bedNode.physicsBody!.collisionBitMask = PhysicsCategory.None
        
        catNode.physicsBody!.categoryBitMask = PhysicsCategory.Cat
        catNode.physicsBody!.collisionBitMask = PhysicsCategory.Block | PhysicsCategory.Edge | PhysicsCategory.Spring
        
        catNode.physicsBody!.contactTestBitMask = PhysicsCategory.Bed | PhysicsCategory.Edge
        
        addHook()
        
//        let rotationContrains = SKConstraint.zRotation(SKRange(lowerLimit: -π/4, upperLimit: π/4))
//        catNode.constraints = [rotationContrains]
        
    }
    
    func sceneTouched(location: CGPoint){
        let targetNode = self.nodeAtPoint(location)
        
        if targetNode.physicsBody == nil {
            return
        }
        
        if targetNode.physicsBody!.categoryBitMask == PhysicsCategory.Block {
            targetNode.removeFromParent()
            runAction(SKAction.playSoundFileNamed("pop.mp3", waitForCompletion: false))
            return
        }
        
        if targetNode.physicsBody!.categoryBitMask == PhysicsCategory.Spring {
            let spring = targetNode as! SKSpriteNode
            spring.physicsBody!.applyImpulse(CGVector(dx: 0, dy: 160), atPoint: CGPoint(x: spring.size.width / 2, y: spring.size.height))
            targetNode.runAction(SKAction.sequence([SKAction.waitForDuration(1), SKAction.removeFromParent()]))
            return
        }
        
        if targetNode.physicsBody?.categoryBitMask == PhysicsCategory.Cat && hookJoint != nil {
            releaseHook()
        }
    }
    
    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
        let touch: UITouch = touches.first as! UITouch
        sceneTouched(touch.locationInNode(self))
    }
    
    func didBeginContact(contact: SKPhysicsContact) {
        let collision: UInt32 = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        if collision == PhysicsCategory.Cat | PhysicsCategory.Bed {
            win()
        }else if collision == PhysicsCategory.Cat | PhysicsCategory.Edge {
            lose()
        }
        
        if collision == PhysicsCategory.Label | PhysicsCategory.Edge {
            let labelNode = contact.bodyA.categoryBitMask == PhysicsCategory.Label ? contact.bodyA.node as! SKLabelNode : contact.bodyB.node as! SKLabelNode
            
            if var userData = labelNode.userData {
                userData["bounceCount"] = (userData["bounceCount"] as! Int) + 1
                if userData["bounceCount"] as! Int == 4{
                    labelNode.removeFromParent()
                }
            }else{
                labelNode.userData = NSMutableDictionary(object: 1 as Int, forKey: "bounceCount")
            }
            
        }
        
        if collision == PhysicsCategory.Cat | PhysicsCategory.Hook {
            catNode.physicsBody!.velocity = CGVector(dx: 0, dy: 0)
            catNode.physicsBody!.angularVelocity = 0
            
            let pinPoint = CGPoint(x: hookNode.position.x, y: hookNode.position.y + hookNode.size.height/2)
            hookJoint = SKPhysicsJointFixed.jointWithBodyA(contact.bodyA, bodyB: contact.bodyB, anchor: pinPoint)
            physicsWorld.addJoint(hookJoint)
        }
    }
    
    func inGameMessage(text: String){
        
        let label = SKLabelNode(fontNamed: "AvenirNext-Regular")
        label.text = text
        label.fontSize = 128.0
        label.fontColor = SKColor.whiteColor()
        
        label.position = CGPoint(x: frame.size.width / 2, y: frame.size.height / 2)
        label.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        label.physicsBody!.collisionBitMask = PhysicsCategory.Edge
        label.physicsBody!.categoryBitMask = PhysicsCategory.Label
        label.physicsBody!.contactTestBitMask = PhysicsCategory.Edge
        label.physicsBody!.restitution = 0.7
        
        addChild(label)
        
        //runAction(SKAction.sequence([SKAction.waitForDuration(3), SKAction.removeFromParent()]))
    }
    
    func newGame(){
        view!.presentScene(GameScene.level(currentLevel))
    }
    
    func lose(){
        
        catNode.physicsBody!.contactTestBitMask = PhysicsCategory.None
        catNode.texture = SKTexture(imageNamed: "cat_awake")
        
        SKTAudio.sharedInstance().pauseBackgroundMusic()
        runAction(SKAction.playSoundFileNamed("lose.mp3", waitForCompletion: false))
        
        inGameMessage("Try again...")
        
        runAction(SKAction.sequence([SKAction.waitForDuration(5), SKAction.runBlock(newGame)]))
    }
    
    func win(){
        catNode.physicsBody = nil
        
        let curlY = bedNode.position.y + catNode.size.height / 3
        let curlPoint = CGPoint(x: bedNode.position.x, y: curlY)
        
        catNode.runAction(SKAction.group([SKAction.moveTo(curlPoint, duration: 0.66), SKAction.rotateToAngle(0, duration: 0.5)]))
        
        inGameMessage("Nice job!")
        
        runAction(SKAction.sequence([SKAction.waitForDuration(5), SKAction.runBlock(newGame)]))
        
        catNode.runAction(SKAction.animateWithTextures([SKTexture(imageNamed: "cat_curlup1"), SKTexture(imageNamed: "cat_curlup2"), SKTexture(imageNamed: "cat_curlup3")], timePerFrame: 0.25))
        
        SKTAudio.sharedInstance().pauseBackgroundMusic()
        runAction(SKAction.playSoundFileNamed("win.mp3", waitForCompletion: false))
    }
    
    override func didSimulatePhysics() {
        if let body = catNode.physicsBody {
            if body.contactTestBitMask != PhysicsCategory.None && fabs(catNode.zRotation) > CGFloat(45).degreesToRadians() {
                if hookJoint == nil {
                    lose()
                }
                
            }
        }
    }
    
    func addHook(){
        hookBaseNode = childNodeWithName("hookBase") as? SKSpriteNode
        if hookBaseNode == nil {
            return
        }
        
        let ceilingFix = SKPhysicsJointFixed.jointWithBodyA(hookBaseNode.physicsBody, bodyB: physicsBody, anchor: CGPointZero)
        physicsWorld.addJoint(ceilingFix)
        
        ropeNode = SKSpriteNode(imageNamed: "rope")
        ropeNode.anchorPoint = CGPoint(x: 0, y: 0.5)
        ropeNode.zRotation = CGFloat(270).degreesToRadians()
        ropeNode.position = hookBaseNode.position
        addChild(ropeNode)
        
        hookNode = SKSpriteNode(imageNamed: "hook")
        hookNode.position = CGPoint(x: hookBaseNode.position.x, y: hookBaseNode.position.y - ropeNode.size.width)
        
        hookNode.physicsBody = SKPhysicsBody(circleOfRadius: hookNode.size.width / 2)
        hookNode.physicsBody!.categoryBitMask = PhysicsCategory.Hook
        hookNode.physicsBody!.contactTestBitMask = PhysicsCategory.Cat
        hookNode.physicsBody!.collisionBitMask = PhysicsCategory.None
        
        addChild(hookNode)
        
        let ropeJoint = SKPhysicsJointSpring.jointWithBodyA(hookBaseNode.physicsBody, bodyB: hookNode.physicsBody, anchorA: hookBaseNode.position, anchorB: CGPoint(x: hookNode.position.x, y: hookNode.position.y + hookNode.size.height/2))
        physicsWorld.addJoint(ropeJoint)
        
        let range = SKRange(lowerLimit: 0.0, upperLimit: 0.0)
        let orientContraint = SKConstraint.orientToNode(hookNode, offset: range)
        ropeNode.constraints = [orientContraint]
        
        hookNode.physicsBody!.applyImpulse(CGVector(dx: 50, dy: 0))
        
        
    }
    
    func releaseHook(){
        catNode.zRotation = 0
        hookNode.physicsBody!.contactTestBitMask = PhysicsCategory.None
        physicsWorld.removeJoint(hookJoint)
        hookJoint = nil
    }
    
}
