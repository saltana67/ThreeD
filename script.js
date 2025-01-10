import * as THREE from 'three'
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { mx_hash_int_3 } from 'three/src/nodes/materialx/lib/mx_noise.js';

console.log("script.js working ok!!!");
console.log("THREE: ", THREE);

const canvas = document.querySelector('canvas.webgl');
const sizes = getCanvasSize();

const scene = new THREE.Scene();

const cameraDistance = 75;
const fov = 50; //degree
const aspect = sizes.width / sizes.height;
const camera = new THREE.PerspectiveCamera(fov,aspect /*,0.1, 2000 */);
//const camera = new THREE.PerspectiveCamera(fov,aspect, 1, 500);
camera.position.z = 3;//cameraDistance;

var cameraAngle=(Math.PI * 2) * .5;
var boxWidth = 50;
var boxHeight = 20;
var boxDepth = 50;

//scene.fog = new THREE.Fog( 0x000000, this.cameraDistance-200, this.cameraDistance+550 );

// this.particleGeometry = new THREE.BufferGeometry();

// this.particleVertexShader = [
//     "attribute vec3 color;",
//     "attribute float opacity;",
//     "varying vec4 vColor;",
//     "void main()",
//     "{",
//     "vColor = vec4( color, opacity );", //     set color associated to vertex; use later in fragment shader.
//     "vec4 mvPosition = modelViewMatrix * vec4( position, 1.0 );",
//     "gl_PointSize = 1.0;",
//     "gl_Position = projectionMatrix * mvPosition;",
//     "}"
// ].join("\n");

// this.particleFragmentShader = [
//     "varying vec4 vColor;",     
//     "void main()", 
//     "{",
//     "gl_FragColor = vColor;",
//     "}"
// ].join("\n");

// this.shaderAttributes = {
//     color: { type: 'c', value: []},
//     opacity: {type: 'f', value: []}
// };
// this.shaderMaterial = new THREE.ShaderMaterial( {
//     uniforms:       {},
//     attributes:     this.shaderAttributes,
//     vertexShader:   this.particleVertexShader,
//     fragmentShader: this.particleFragmentShader,
//     transparent:    true
// });

//const particlesGeometry = new THREE.SphereGeometry(1, 32, 32);
const particlesGeometry = new THREE.PlaneGeometry(2,2,boxWidth,boxDepth);
particlesGeometry.rotateX(Math.PI/2);

let pointPos = particlesGeometry.getAttribute("position").array

function updateBoxValues(coeff=1.0){
    const maxAmpli = 0.5*coeff;
    for( var j = 0; j < boxDepth+1; j++){
        const dcoef = j/boxDepth;
        const ampli = Math.sin(dcoef*Math.PI)*maxAmpli;
        const iOffset=j*(boxWidth+1)*3;
        //console.log("j: ", j, ", dcoef:", dcoef,", iOffset: ", iOffset);
        for( var i = 0; i < boxWidth+1; /*boxWidth * boxDepth;*/ i++){
            const wcoef = i/boxWidth;
            const yV = Math.sin(wcoef*Math.PI*2)*ampli;
            const indx = iOffset+(i*3)+1;
            //console.log("i: ", i, ", wcoef: ", wcoef, ", indx: ", indx);
            pointPos[iOffset+(i*3)+1] = yV;
        }
    }
    //pointPos.needsUpdate = true; 
    particlesGeometry.getAttribute("position").needsUpdate = true;
}

updateBoxValues(0);

const particlesMaterial = new THREE.ShaderMaterial({
    vertexShader: THREE.ShaderLib.points.vertexShader,
    fragmentShader: THREE.ShaderLib.points.fragmentShader,
    uniforms: THREE.UniformsUtils.clone(THREE.ShaderLib.points.uniforms)
});

Object.defineProperty(particlesMaterial, "size", { value: 5, writable: true });
//Object.defineProperty(particlesMaterial, "sizeAttenuation", { value: true, writable: true });
//Object.defineProperty(particlesMaterial, "isPointsMaterial", { value: true, writable: true });

//particlesMaterial.isPointsMaterial = true;
//particlesMaterial.size = 2.0;
particlesMaterial.sizeAttenuation = true;

console.log("particlesMaterial.uniforms.size.value:",particlesMaterial.uniforms.size.value);
particlesMaterial.uniforms["size"].value=5;
//particlesMaterial.uniforms["scale"].value=1;
//particlesMaterial.needsUpdate = true;

const particlesMaterial2 = new THREE.PointsMaterial({
    size: 0.01,
    sizeAttenuation: true,
    onBeforeCompile: (shader) => {
        console.log("shader:", shader);
    }
});

console.log("particlesMaterial:", particlesMaterial);

const particles = new THREE.Points(particlesGeometry, particlesMaterial);
console.log("particles:", particles);

scene.add(particles);

scene.add(camera);

const renderer = new THREE.WebGLRenderer({
    canvas: canvas,
    antialias: true
});

renderer.setSize(sizes.width, sizes.height,false);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.1;

const theClock = new THREE.Clock();

function animate(timeStamp = 0) {
    requestAnimationFrame(animate);
//    boxGroup.userData.update(timeStamp);
//    composer.render(scene, camera);
    //console.log("timeStamp: ", timeStamp, ", Math.sin(timeStamp): ", Math.sin(timeStamp));
    //console.log("theClock.elapsedTime():", theClock.getElapsedTime());
    const et = theClock.getElapsedTime();
    const elp = (et/2)*Math.PI;
    //console.log("elp:", elp);
    const elpSin = Math.sin(elp);
    //console.log("elpSin:", elpSin);
    updateBoxValues(elpSin);
    renderer.render(scene,camera);
    controls.update();
}
theClock.start();

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




