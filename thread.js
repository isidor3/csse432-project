window.onload = function(){
	place();
	init();
}

function comp(a,b){
	if(parseInt(a.id) < parseInt(b.id)){
		return -1;
	}else{
		return 1;
	}
}

function place(){
	var core = $('#core')[0];
	console.log(core);
	var faux = d3.select("#faux");
	var posts = faux.selectAll("div")[0];
	posts.sort(comp);
	for(var i = 0; i<posts.length; i++){
		core.appendChild(posts[i]);
	}
}

function init(){
	var go = true;
	var count = 0;
	while(go){
		var post = $("#" + count);
		if(post.length){
			post = post[0];
			var id = document.createElement("div");
			id.className += "postNumber";
			var text = document.createTextNode("Relative post number:" + count);
			id.appendChild(text);
			var first = post.firstChild;
			// post.appendChild(id);
			post.insertBefore(id, first);
			count += 1;
		}else{
			go = false;
		}
	}
}

function post(){
	$("#postform").submit();
}