import * as THREE from 'three'
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

console.log("script.js working ok!!!");
console.log("THREE: ", THREE);

const canvas = document.querySelector('canvas.webgl');

const scene = new THREE.Scene();

const boxGeo = new THREE.BoxGeometry(1,1,1);
const boxMat = new THREE.MeshBasicMaterial({color: 0xff0000});
const box = new THREE.Mesh(boxGeo, boxMat);

scene.add(box);

const sizes = getCanvasSize();

const fov = 75; //degree
const aspect = sizes.width / sizes.height;
const camera = new THREE.PerspectiveCamera(fov,aspect /*,0.1, 2000 */);
camera.position.z = 3;

scene.add(camera);

const renderer = new THREE.WebGLRenderer({
    canvas: canvas,
    antialias: true
});

renderer.setSize(sizes.width, sizes.height,false);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.1;

function animate(timeStamp = 0) {
    requestAnimationFrame(animate);
//    boxGroup.userData.update(timeStamp);
//    composer.render(scene, camera);
    renderer.render(scene,camera);
    controls.update();
}

animate();

function getCanvasSize() {
    const canvasFrame = document.querySelector('div.canvasFrame');
//    const canvasFrameStyle = getComputedStyle(canvasFrame);
//    const canvasFrameStyle = getComputedStyle(canvas);
    return {
            width: window.innerWidth
        ,   height: window.innerHeight
//            width:  document.body.clientWidth
//        ,   height: document.body.clientHeight

/* growing endlesssly */
//            width:  document.body.scrollWidth
//        ,   height: document.body.scrollHeight

/* height growing endlesssly */
//            width:  canvasFrame.clientWidth
//       ,   height: canvasFrame.clientHeight

/* height growing endlesssly on every resize, width only growing */
//            width:  canvasFrame.scrollWidth
//        ,   height: canvasFrame.scrollHeight


/* height growing endlesssly */
//            width:  canvasFrame.offsetWidth
//        ,   height: canvasFrame.offsetHeight


//            width:  canvasFrameStyle.width
//        ,   height: canvasFrameStyle.height

//            width:  canvas.scrollWidth
//        ,   height: canvas.scrollHeight
    };
}

function handleWindowResize() {
    const canvasSize = getCanvasSize();
    console.log("canvasSize: ", canvasSize);
    camera.aspect = canvasSize.width / canvasSize.height ;
    camera.updateProjectionMatrix();
    renderer.setSize(canvasSize.width, canvasSize.height, false);
}
window.addEventListener("resize", handleWindowResize, false);




